-- Smart-path next-edit prediction (Cursor Tab-style), implemented locally in
-- lua/nextedit/. See that module for the architecture; this file wires it
-- into lazy.nvim and owns the unified <Tab> keymap:
--
--   insert <Tab>: minuet ghost text > pending next-edit > literal tab
--   normal <Tab>: pending next-edit > jumplist (<C-i>)
--
-- Requires GEMINI_API_KEY in the environment (or point `provider`/`end_point`
-- at any OpenAI-compatible endpoint: DeepSeek, OpenRouter, Copilot/Zen proxy).

return {
  {
    name = 'nextedit',
    dir = vim.fn.stdpath 'config' .. '/lua/nextedit',
    event = 'VeryLazy',
    config = function()
      local nextedit = require 'nextedit'
      nextedit.setup {
        provider = 'gemini',
        model = 'gemini-2.5-flash',
        api_key = 'GEMINI_API_KEY',
        -- DeepSeek instead (non-reasoning model id; thinking stays off):
        --   provider = 'openai_compatible',
        --   model = 'deepseek-chat',
        --   end_point = 'https://api.deepseek.com/chat/completions',
        --   api_key = 'DEEPSEEK_API_KEY',
        auto_trigger = true,
      }

      -- Insert-mode <Tab>: fast path first (minuet ghost text), then the
      -- smart path (pending next-edit), then a literal tab. The nvim-cmp
      -- popup is confirmed with <CR> (see cmp.lua), never with Tab.
      vim.keymap.set('i', '<Tab>', function()
        local ok, minuet_vt = pcall(require, 'minuet.virtualtext')
        if ok and minuet_vt.action.is_visible() then
          minuet_vt.action.accept()
        elseif nextedit.is_pending() then
          nextedit.accept()
        else
          local keys = vim.api.nvim_replace_termcodes('<Tab>', true, false, true)
          vim.api.nvim_feedkeys(keys, 'n', false)
        end
      end, { desc = 'Accept ghost text / next-edit, or Tab', silent = true })

      -- Normal-mode <Tab>: apply the pending next-edit and jump to the next
      -- one ("Tab to jump"); otherwise keep the default jumplist motion.
      vim.keymap.set('n', '<Tab>', function()
        if not nextedit.accept() then
          local keys = vim.api.nvim_replace_termcodes('<C-i>', true, false, true)
          vim.api.nvim_feedkeys(keys, 'n', false)
        end
      end, { desc = 'Apply next-edit or jump forward', silent = true })

      -- Manual trigger / dismiss.
      vim.keymap.set({ 'n', 'i' }, '<A-n>', function() nextedit.trigger { manual = true } end, { desc = 'Predict next edit' })
      vim.keymap.set('n', '<A-e>', nextedit.dismiss, { desc = 'Dismiss next-edit' })
    end,
  },
}
