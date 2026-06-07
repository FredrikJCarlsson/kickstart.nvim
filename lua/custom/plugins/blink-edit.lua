-- Sweep next-edit (Cursor-style "predict my next edit & jump there") via the
-- local `sweepai/sweep-next-edit` model on Ollama.
--
-- This is the NES half of the Cursor experience and complements minuet.lua:
--   * minuet  → fill-in-the-middle completion as you type  (<Tab>)
--   * sweep   → predicts your *next edit anywhere* and jumps  (<C-y>)
--
-- Requires Ollama running with the model pulled:
--   ollama pull sweepai/sweep-next-edit   (you already have it)
--   ollama serve
--
-- NOTE: accept is bound to <C-y>, NOT <Tab>, because minuet owns <Tab> for FIM
-- completion. Adjust the keymaps below if you'd rather flip that.
return {
  'BlinkResearchLabs/blink-edit.nvim',
  event = 'InsertEnter',
  config = function()
    require('blink-edit').setup {
      llm = {
        provider = 'sweep', -- uses the <|file_sep|> original/current/updated format
        backend = 'ollama',
        url = 'http://localhost:11434',
        model = 'sweepai/sweep-next-edit:latest',
        temperature = 0.0,
        max_tokens = 512,
        timeout_ms = 8000,
      },
      -- Also predict on idle in normal mode (Cursor-like jump suggestions),
      -- not just while typing.
      normal_mode = {
        enabled = true,
      },
      keymaps = {
        insert = {
          accept = '<C-y>', -- accept whole suggested edit (avoid clashing with minuet's <Tab>)
          accept_line = '<C-j>', -- accept line-by-line
          clear = '<C-]>',
          reject = '<Esc>',
        },
        normal = {
          accept = '<C-y>',
          accept_line = '<C-j>',
        },
      },
    }
  end,
}
