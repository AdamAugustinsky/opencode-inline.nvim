local M = {}

local default_config = {
  script_path = nil,
  strip_codeblock = true,
  default_args = {},
  input_prompt = "AI instruction: ",
  mappings = {
    prompt = "<leader>k",
    prompt_desc = "AI: Transform with Claude",
  },
  presets = {
    explain = {
      key = "<leader>ke",
      instruction = "Explain the selected code succinctly as comments directly in the code. Return only code.",
      desc = "AI: Explain in comments",
      args = {},
    },
    refactor = {
      key = "<leader>kr",
      instruction = "Refactor the code to be more readable and idiomatic. Keep behavior the same.",
      desc = "AI: Refactor",
      args = {},
    },
    tests = {
      key = "<leader>kt",
      instruction = "Write unit tests for the selected code. Match the project's typical testing style.",
      desc = "AI: Generate tests",
      args = {},
    },
  },
  cmd_map = nil,
  env = {},
}

local state = {
  config = nil,
  keymaps = {},
}

local function shellescape(str)
  return vim.fn.shellescape(str)
end

local function resolve_script_path(user_path)
  if user_path and user_path ~= "" then
    local expanded = vim.fn.expand(user_path)
    local absolute = vim.fn.fnamemodify(expanded, ":p")
    if vim.fn.filereadable(absolute) == 1 or vim.fn.executable(absolute) == 1 then
      return absolute
    end
  end

  local in_path = vim.fn.exepath("opencode-stdin")
  if in_path ~= "" then
    return in_path
  end

  local source = debug.getinfo(1, "S").source
  source = source:gsub("^@", "")
  local root = vim.fn.fnamemodify(source, ":p:h:h:h")
  local bundled = vim.fs.joinpath(root, "scripts", "opencode-stdin")
  if vim.fn.filereadable(bundled) == 1 or vim.fn.executable(bundled) == 1 then
    return bundled
  end

  return nil
end

local function ensure_config()
  if state.config then
    return state.config
  end

  state.config = vim.deepcopy(default_config)
  state.config.script_path = resolve_script_path()
  return state.config
end

local function ensure_script(cfg)
  cfg = cfg or ensure_config()
  if not cfg.script_path or cfg.script_path == "" then
    cfg.script_path = resolve_script_path()
  end

  if not cfg.script_path then
    vim.notify("opencode-inline.nvim: unable to locate opencode-stdin script", vim.log.levels.ERROR)
    return nil
  end

  if vim.fn.executable(cfg.script_path) ~= 1 then
    vim.notify("opencode-inline.nvim: script not executable at " .. cfg.script_path, vim.log.levels.ERROR)
    return nil
  end

  return cfg.script_path
end

local function is_blank(value)
  return not value or value:match("^%s*$") ~= nil
end

local function buffer_filetype(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local ok, ft = pcall(vim.api.nvim_buf_get_option, bufnr, "filetype")
  if not ok or not ft or ft == "" then
    ft = vim.bo.filetype ~= "" and vim.bo.filetype or ""
  end
  if not ft or ft == "" then
    ft = "text"
  end
  return ft
end

local function build_command(cfg, instruction, extra_args, range, bufnr)
  if is_blank(instruction) then
    return nil
  end

  local script = ensure_script(cfg)
  if not script then
    return nil
  end

  local parts = {}

  local ft = buffer_filetype(bufnr)
  parts[#parts + 1] = string.format("NVIM_FILETYPE=%s", shellescape(ft))
  local strip_flag = cfg.strip_codeblock and "1" or "0"
  parts[#parts + 1] = string.format("CLAUDE_STRIP_CODEBLOCK=%s", shellescape(strip_flag))

  if cfg.env then
    for key, value in pairs(cfg.env) do
      if not is_blank(key) and value ~= nil then
        parts[#parts + 1] = string.format("%s=%s", key, shellescape(tostring(value)))
      end
    end
  end

  parts[#parts + 1] = shellescape(script)
  parts[#parts + 1] = shellescape(instruction)

  for _, arg in ipairs(cfg.default_args or {}) do
    parts[#parts + 1] = shellescape(arg)
  end
  for _, arg in ipairs(extra_args or {}) do
    parts[#parts + 1] = shellescape(arg)
  end

  local prefix
  if range and range[1] and range[2] then
    prefix = string.format("%d,%d!", range[1], range[2])
  else
    prefix = "'<,'>!"
  end

  return prefix .. " " .. table.concat(parts, " ")
end

local function apply_filter(cfg, instruction, extra_args, range, bufnr)
  cfg = cfg or ensure_config()
  local command = build_command(cfg, instruction, extra_args, range, bufnr)
  if not command then
    return
  end
  vim.cmd(command)
end

local function prompt_for_instruction(cfg)
  cfg = cfg or ensure_config()
  vim.ui.input({ prompt = cfg.input_prompt }, function(instruction)
    if is_blank(instruction) then
      return
    end
    apply_filter(cfg, instruction)
  end)
end

local function record_keymap(mode, lhs)
  state.keymaps[#state.keymaps + 1] = { mode = mode, lhs = lhs }
end

local function clear_keymaps()
  for _, map in ipairs(state.keymaps) do
    pcall(vim.keymap.del, map.mode, map.lhs)
  end
  state.keymaps = {}
end

local function register_preset(cfg, name, preset)
  if not preset or not preset.key or preset.key == "" then
    return
  end

  vim.keymap.set("v", preset.key, function()
    apply_filter(cfg, preset.instruction, preset.args)
  end, { desc = preset.desc or ("Claude preset: " .. name), silent = true })
  record_keymap("v", preset.key)
end

local function register_prompt_mapping(cfg)
  if cfg.mappings and cfg.mappings.prompt and cfg.mappings.prompt ~= "" then
    vim.keymap.set("v", cfg.mappings.prompt, function()
      prompt_for_instruction(cfg)
    end, { desc = cfg.mappings.prompt_desc or "AI: Transform with Claude", silent = true })
    record_keymap("v", cfg.mappings.prompt)
  end
end

local function register_cmd_mapping(cfg)
  if not cfg.cmd_map or cfg.cmd_map == "" then
    return
  end

  if not cfg.mappings or not cfg.mappings.prompt or cfg.mappings.prompt == "" then
    return
  end

  vim.keymap.set("v", cfg.cmd_map, function()
    local rhs = cfg.mappings.prompt
    local keys = vim.api.nvim_replace_termcodes(rhs, true, false, true)
    vim.api.nvim_feedkeys(keys, "x", false)
  end, { desc = "Cmd+K -> Claude inline", silent = true })
  record_keymap("v", cfg.cmd_map)
end

local function register_user_command(cfg)
  pcall(vim.api.nvim_del_user_command, "OpencodeInline")

  vim.api.nvim_create_user_command("OpencodeInline", function(command_opts)
    local instruction = command_opts.args
    if is_blank(instruction) then
      prompt_for_instruction(cfg)
      return
    end
    local range
    if command_opts.range == 2 then
      range = { command_opts.line1, command_opts.line2 }
    end
    apply_filter(cfg, instruction, nil, range)
  end, { range = true, nargs = "*", desc = "Send selected lines through Claude inline" })
end

function M.apply_visual(instruction, extra_args)
  local cfg = ensure_config()
  apply_filter(cfg, instruction, extra_args)
end

function M.prompt_visual()
  local cfg = ensure_config()
  prompt_for_instruction(cfg)
end

function M.setup(opts)
  opts = opts or {}
  local cfg = vim.tbl_deep_extend("force", vim.deepcopy(default_config), opts)
  cfg.script_path = resolve_script_path(cfg.script_path)
  state.config = cfg

  ensure_script(cfg)

  clear_keymaps()
  register_prompt_mapping(cfg)

  if cfg.presets then
    for name, preset in pairs(cfg.presets) do
      register_preset(cfg, name, preset)
    end
  end

  register_cmd_mapping(cfg)
  register_user_command(cfg)
end

return M
