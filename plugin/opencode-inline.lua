if vim.g.loaded_opencode_inline then
  return
end
vim.g.loaded_opencode_inline = true

require("opencode_inline").setup()
