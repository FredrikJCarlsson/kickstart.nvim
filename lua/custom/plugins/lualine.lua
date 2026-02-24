return {
  'nvim-lualine/lualine.nvim',
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  config = function()
    require('lualine').setup {
      options = {
        icons_enabled = true,
        theme = 'auto',
        component_separators = { left = '', right = '' },
        section_separators = { left = '', right = '' },
        disabled_filetypes = {
          statusline = {},
          winbar = {},
        },
        ignore_focus = {},
        always_divide_middle = true,
        always_show_tabline = true,
        globalstatus = false,
        refresh = {
          statusline = 1000,
          tabline = 1000,
          winbar = 1000,
          refresh_time = 16, -- ~60fps
          events = {
            'WinEnter',
            'BufEnter',
            'BufWritePost',
            'SessionLoadPost',
            'FileChangedShellPost',
            'VimResized',
            'Filetype',
            'CursorMoved',
            'CursorMovedI',
            'ModeChanged',
          },
        },
      },
      sections = {
        lualine_a = { 'mode' },
        lualine_b = { 'branch', 'diff', 'diagnostics' },
        lualine_c = { 'filename' },
        lualine_x = {
          {
            function()
              local clients = package.loaded['copilot'] and vim.lsp.get_clients { name = 'copilot', bufnr = 0 } or {}
              if #clients > 0 then
                local status = require('copilot.status').data.status
                if status == 'InProgress' then
                  return ' …'
                elseif status == 'Warning' then
                  return ' !'
                else
                  return ' '
                end
              end
              return ''
            end,
            color = function()
              local clients = package.loaded['copilot'] and vim.lsp.get_clients { name = 'copilot', bufnr = 0 } or {}
              if #clients > 0 then
                local status = require('copilot.status').data.status
                if status == 'Warning' then
                  return { fg = '#e5c07b' }
                elseif status == 'InProgress' then
                  return { fg = '#61afef' }
                end
                return { fg = '#98c379' }
              end
            end,
          },
          'encoding',
          'fileformat',
          'filetype',
        },
        lualine_y = { 'progress' },
        lualine_z = { 'location' },
      },
      inactive_sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = { 'filename' },
        lualine_x = { 'location' },
        lualine_y = {},
        lualine_z = {},
      },
      tabline = {},
      winbar = {},
      inactive_winbar = {},
      extensions = {},
    }
  end,
}
