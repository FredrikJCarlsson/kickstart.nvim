-- You can add your own plugins here or in other files in this directory!
--  I promise not to create any merge conflicts in this directory :)
--
-- See the kickstart.nvim README for more information
vim.g.autoformat = false
vim.o.clipboard = 'unnamedplus'

vim.o.wrap = false

local function paste()
  return {
    vim.fn.split(vim.fn.getreg '', '\n'),
    vim.fn.getregtype '',
  }
end

vim.g.clipboard = {
  name = 'OSC 52',
  copy = {
    ['+'] = require('vim.ui.clipboard.osc52').copy '+',
    ['*'] = require('vim.ui.clipboard.osc52').copy '*',
  },
  paste = {
    ['+'] = paste,
    ['*'] = paste,
  },
}

return {}
