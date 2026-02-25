return {
  { -- Useful plugin to show you pending keybinds.
    'folke/which-key.nvim',
    event = 'VimEnter',
    opts = {
      -- delay between pressing a key and opening which-key (milliseconds)
      delay = 0,
      icons = { mappings = vim.g.have_nerd_font },

      -- Document existing key chains
      spec = {
        { '<leader>g', group = 'Git', icon = '' },
        { '<leader>s', group = '[S]earch', mode = { 'n', 'v' } },
        { '<leader>t', group = '[T]oggle' },
        { '<leader>h', group = 'Git [H]unk', mode = { 'n', 'v' } },
        { '<C-s>', '<cmd>w<cr>', desc = 'Save buffer', mode = { 'n', 'i', 'v' } },
        { '<leader>qq', '<cmd>qa<cr>', desc = 'Quit all' },
      },
    },
  },
}
