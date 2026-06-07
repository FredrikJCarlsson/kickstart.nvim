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
    -- Read .vscode/tasks.json (VS Code-compatible tasks) alongside builtins.
    templates = {
      'builtin',
      'user.zig_build',
      'user.msbuild_debug',
      'user.syncAndStartGdb',
      -- "user.UP2210V3",
    },
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
  config = function(_, opts)
    require('overseer').setup(opts)

    -- .vscode/tasks.json tasks are picked up automatically and show up in
    -- :OverseerRun. The command below runs a tasks.json task directly by label.
    vim.api.nvim_create_user_command('OverseerRunVscodeTask', function(params)
      local overseer = require 'overseer'
      if params.args == '' then
        -- No label given: open the picker (same as :OverseerRun).
        overseer.run_template {}
        return
      end
      overseer.run_template({ name = params.args }, function(task, err)
        if not task then vim.notify(err or ('No task named: ' .. params.args), vim.log.levels.ERROR) end
      end)
    end, {
      nargs = '?',
      desc = 'Run a .vscode/tasks.json task by label',
    })
  end,
  -- stylua: ignore
  keys = {
    { "<leader>o",  nil,                            desc = "Overseer",          },
    { "<leader>ow", "<cmd>OverseerToggle<cr>",      desc = "Task list",         },
    { "<leader>oo", "<cmd>OverseerRun<cr>",         desc = "Run task",          },
    { "<leader>oq", "<cmd>OverseerQuickAction<cr>", desc = "Action recent task",},
    { "<leader>oi", "<cmd>OverseerInfo<cr>",        desc = "Overseer Info",     },
    { "<leader>ob", "<cmd>OverseerBuild<cr>",       desc = "Task builder",      },
    { "<leader>ot", "<cmd>OverseerTaskAction<cr>",  desc = "Task action",       },
    { "<leader>oc", "<cmd>OverseerClearCache<cr>",  desc = "Clear cache",       },
  },
}
