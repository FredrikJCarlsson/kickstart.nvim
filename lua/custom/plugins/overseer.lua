return {
  'stevearc/overseer.nvim',
  cmd = {
    'OverseerOpen',
    'OverseerClose',
    'OverseerToggle',
    'OverseerSaveBundle',
    'OverseerLoadBundle',
    'OverseerDeleteBundle',
    'OverseerRunCmd',
    'OverseerRun',
    'OverseerInfo',
    'OverseerBuild',
    'OverseerQuickAction',
    'OverseerTaskAction',
    'OverseerClearCache',
  },
  opts = {
    dap = false,
    task_list = {
      bindings = {
        ['<C-h>'] = false,
        ['<C-j>'] = false,
        ['<C-k>'] = false,
        ['<C-l>'] = false,
      },
    },
    form = {
      win_opts = {
        winblend = 0,
      },
    },
    confirm = {
      win_opts = {
        winblend = 0,
      },
    },
    task_win = {
      win_opts = {
        winblend = 0,
      },
    },
  },
  config = function()
    require('overseer').setup {
      templates = {
        'builtin',
        'user.zig_build',
        'user.msbuild_debug',
        'user.syncAndStartGdb',
        -- "user.UP2210V3",
      },
    }
  end,
  -- stylua: ignore
  keys = {
    { "<leader>o",  nil,                            desc = "Overseer",           icon = '󰮔' },
    { "<leader>ow", "<cmd>OverseerToggle<cr>",      desc = "Task list",          icon = '󱉯' },
    { "<leader>oo", "<cmd>OverseerRun<cr>",         desc = "Run task",           icon = '' },
    { "<leader>oq", "<cmd>OverseerQuickAction<cr>", desc = "Action recent task", icon = '⚡' },
    { "<leader>oi", "<cmd>OverseerInfo<cr>",        desc = "Overseer Info",      icon = '' },
    { "<leader>ob", "<cmd>OverseerBuild<cr>",       desc = "Task builder",       icon = '' },
    { "<leader>ot", "<cmd>OverseerTaskAction<cr>",  desc = "Task action",        icon = '' },
    { "<leader>oc", "<cmd>OverseerClearCache<cr>",  desc = "Clear cache",        icon = '󰃢' },
  },
}
