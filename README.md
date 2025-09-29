# opencode-inline.nvim

Cursor-style inline AI transforms for Neovim visual selections using the `opencode` CLI.

## Features
- Visual mode filter that pipes selections to `opencode run` with your instruction and replaces the code inline.
- Bundled stdin wrapper script that builds a structured prompt with filetype fences for better completions.
- Ready-to-use keymaps for prompting (`<leader>k`) and quick presets for explain/refactor/test flows.
- Optional GUI-friendly mapping (e.g. `<D-k>`) that reuses the prompt mapping.
- User command `:OpencodeInline` for piping a range or prompting manually.

## Requirements
- [opencode CLI](https://github.com/opencode) available on your `PATH`.
- Neovim 0.9+ (for `vim.ui.input` / `vim.fs.joinpath`).

## Installation
Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "opencode-dev/opencode-inline.nvim",
  config = function()
    require("opencode_inline").setup()
  end,
}
```

### Lazy loading with `lazy.nvim`

The plugin exposes both keymaps and the `:OpencodeInline` command, so you can defer loading until one of those entry points is used:

```lua
{
  "opencode-dev/opencode-inline.nvim",
  cmd = { "OpencodeInline" },
  keys = {
    {
      "<leader>k",
      mode = "v",
      desc = "AI: Transform with opencode",
      function()
        require("opencode_inline").prompt_visual()
      end,
    },
    {
      "<leader>kr",
      mode = "v",
      desc = "AI: Refactor",
      function()
        require("opencode_inline").apply_visual("Refactor the code to be more readable and idiomatic. Keep behavior the same.")
      end,
    },
  },
  config = function()
    require("opencode_inline").setup({
      cmd_map = vim.g.neovide and "<D-k>" or nil,
    })
  end,
}
```

With this setup `lazy.nvim` loads the plugin the first time you hit one of the registered keys or call `:OpencodeInline`, keeping startup fast while still making the AI workflow available on demand.

The bundled script lives at `scripts/opencode-stdin` inside the plugin and is executable out of the box. If you want to call it directly from your shell, add it to your `PATH` (e.g. symlink into `~/.local/bin`).

## Usage
1. Visually select the code you want to transform.
2. Press `<leader>k` (default). You will be prompted for an instruction such as `Refactor for readability` or `Convert to async/await`.
3. The selection is replaced with the AI output, limited to the first fenced code block to keep buffers clean. Undo with a single `u` if needed.

Preset mappings:
- `<leader>ke` — add inline comments explaining the code.
- `<leader>kr` — refactor for readability.
- `<leader>kt` — generate unit tests matching the project style.

GUI shortcut (disabled by default): set `cmd_map = "<D-k>"` in your setup to forward Cmd+K to the prompt mapping in clients that support the Cmd key.

### `:OpencodeInline` command
You can also run `:OpencodeInline {instruction}` with a visual selection or explicit range (e.g. `:5,20OpencodeInline Optimize this`). When called without an instruction it falls back to the interactive prompt.

## Configuration
Call `setup` with your preferences. All fields are optional; the defaults mimic Cursor’s Cmd+K flow.

```lua
require("opencode_inline").setup({
  script_path = nil,            -- custom path to opencode-stdin (auto-detected otherwise)
  strip_codeblock = true,       -- keep only the first fenced block from responses
  default_args = {},            -- extra args to always pass to opencode run (e.g. {"--model", "provider/model"})
  env = {},                     -- extra env vars to add before the command
  input_prompt = "AI instruction: ",
  mappings = {
    prompt = "<leader>k",
    prompt_desc = "AI: Transform with opencode",
  },
  presets = {
    explain = { key = "<leader>ke", instruction = "Explain…", desc = "AI: Explain" },
    refactor = { key = "<leader>kr", instruction = "Refactor…", desc = "AI: Refactor" },
    tests = { key = "<leader>kt", instruction = "Write tests…", desc = "AI: Tests" },
  },
  cmd_map = nil,                -- set to "<D-k>" (or similar) in GUIs that support Cmd
})
```

Disable or change mappings by setting their keys to `false`/`nil` or replacing them with your preferred shortcuts. Add new presets by extending the `presets` table; each entry accepts `key`, `instruction`, optional `desc`, and optional `args` (extra CLI flags).

## Wrapper script details
`scripts/opencode-stdin` accepts an instruction as the first argument and forwards everything else to `opencode run`. It reads the visual selection from stdin, detects the buffer filetype via `NVIM_FILETYPE`, and wraps the request in a deterministic system prompt. Set `OPCODE_STRIP_CODEBLOCK=0` to return the full textual response instead of stripping to the first fenced block.

## Tips
- Yank to a register before transforming if you want a manual diff.
- Combine with tools like telescope/dressing to build preset pickers on top of `require("opencode_inline").apply_visual`.
- Pass `--session`/`--continue`/`--agent` flags via `default_args` or individual preset `args` for long-running conversations or custom agents.

Happy inline prompting!
