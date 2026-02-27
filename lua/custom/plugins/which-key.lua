return {
  { -- Useful plugin to show you pending keybinds.
    'folke/which-key.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    event = 'VimEnter',
    opts = {
      -- delay between pressing a key and opening which-key (milliseconds)
      delay = 0,
      icons = { mappings = vim.g.have_nerd_font },

      -- Document existing key chains
      spec = {
        { '<leader>g', group = 'Git', icon = '' },
        { '<leader>c', group = 'Code', icon = '' },
        { '<leader>f', group = 'Find', icon = '󰮗' },
        { '<leader>b', group = 'Buffer', icon = '󰈙' },
        { '<leader>gh', group = 'Git Hunk', mode = { 'n', 'v' } },
        { '<leader>s', group = 'Search', mode = { 'n', 'v' } },
        { '<leader>t', group = 'Toggle' },
        { '<leader>u', group = 'UI', icon = '󰹑' },

        { '<C-s>', '<cmd>w<cr>', desc = 'Save buffer', mode = { 'n', 'i', 'v' } },
        { '<leader>qq', '<cmd>qa<cr>', desc = 'Quit all' },

        -- snacks
        { '<leader><space>', desc = '󰈞' },
        { '<leader>,', icon = '' },
        { '<leader>/', icon = '' },
        { '<leader>:', icon = '' },
        { '<leader>n', icon = '' },
        { '<leader>e', icon = '' },
        { '<leader>fb', icon = '' },
        { '<leader>fc', icon = '' },

        -- overseer
        { '<leader>o', group = 'Overseer', icon = '󰮔' },
        { '<leader>ow', icon = '󱉯' },
        { '<leader>oo', icon = '' },
        { '<leader>oq', icon = '⚡' },
        { '<leader>oi', icon = '' },
        { '<leader>ob', icon = '' },
        { '<leader>ot', icon = '' },
        { '<leader>oc', icon = '󰃢' },

        -- File
        { '<leader>F', group = 'File', icon = '' },

        -- LSP
        { 'ga', group = 'Calls', icon = '' },
      },
    },
  },
}
