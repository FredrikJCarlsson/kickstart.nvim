-- FAST PATH of the two-tier completion setup: local FIM model for inline
-- ghost text (Cursor-style). The SMART PATH (structured, LSP-aware next-edits
-- with cross-file propagation) lives in lua/nextedit/ - see
-- custom/plugins/nextedit.lua, which also owns the unified <Tab> keymap:
-- minuet ghost text > pending next-edit > literal tab.
--
-- Requires a running Ollama with a FIM-capable model, e.g.:
--   ollama pull qwen2.5-coder:1.5b-base   (or :3b-base / :7b-base, stronger)
--   ollama serve   (or `brew services start ollama`)
--
-- IMPORTANT: use the *-base* model, NOT the instruct variant. The instruct
-- (chat-tuned) model ignores the FIM tokens and returns prose; the base model
-- does true fill-in-the-middle and returns raw code.
--
-- Verify the exact FIM special tokens against the Qwen2.5-Coder model card
-- for your tag - token spellings occasionally differ between releases.
return {
  'milanglacier/minuet-ai.nvim',
  dependencies = { 'nvim-lua/plenary.nvim' },
  event = 'InsertEnter',
  config = function()
    require('minuet').setup {
      provider = 'openai_fim_compatible',
      n_completions = 1,
      context_window = 4096,
      -- Debounce keystrokes; in-flight requests are superseded when the user
      -- keeps typing - the biggest perceived-speed win for a local model.
      debounce = 150,
      throttle = 300,

      provider_options = {
        openai_fim_compatible = {
          -- Ollama ignores the key, but minuet requires a non-empty value;
          -- TERM is always set in a shell environment.
          api_key = 'TERM',
          name = 'Ollama',
          end_point = 'http://localhost:11434/v1/completions',
          model = 'qwen2.5-coder:1.5b-base',
          -- Stream partial results so ghost text can appear before the
          -- request_timeout window closes (matters for a local model).
          stream = true,
          optional = {
            max_tokens = 256,
            temperature = 0.2,
            top_p = 0.9,
            stop = { '<|endoftext|>', '<|fim_pad|>', '<|file_sep|>' },
          },
          -- qwen2.5-coder FIM: wrap context in the model's fill-in-the-middle
          -- special tokens ourselves. Without this, Ollama/llama.cpp returns
          -- chatty prose instead of a raw code completion. `suffix = false`
          -- because llama.cpp's /v1/completions ignores the OpenAI `suffix`
          -- field, so we embed the after-cursor text in the prompt instead.
          template = {
            prompt = function(context_before_cursor, context_after_cursor)
              return '<|fim_prefix|>' .. context_before_cursor .. '<|fim_suffix|>' .. context_after_cursor .. '<|fim_middle|>'
            end,
            suffix = false,
          },
        },
      },

      -- Cloud alternative for the fast path (Gemini Flash, thinking off):
      -- provider = 'gemini',
      -- provider_options = {
      --   gemini = {
      --     model = 'gemini-2.5-flash',
      --     stream = true,
      --     api_key = 'GEMINI_API_KEY',
      --     end_point = 'https://generativelanguage.googleapis.com/v1beta/models',
      --     optional = {
      --       generationConfig = {
      --         maxOutputTokens = 256,
      --         -- Disable thinking for gemini 2.5 models (3.x: thinkingLevel = 'minimal')
      --         thinkingConfig = { thinkingBudget = 0 },
      --       },
      --     },
      --   },
      -- },

      virtualtext = {
        -- Auto-show ghost text in these filetypes (empty = manual trigger only).
        auto_trigger_ft = { 'c', 'cpp', 'lua', 'python', 'go', 'rust', 'cs', 'zig', 'javascript', 'typescript', 'tsx' },
        keymap = {
          -- Whole-suggestion accept is <Tab>, wired in custom/plugins/nextedit.lua
          -- together with the smart-path next-edit accept.
          accept = nil,
          accept_line = '<A-a>',
          accept_n_lines = '<A-z>',
          prev = '<A-[>',
          next = '<A-]>',
          dismiss = '<A-e>',
        },
      },
    }

    -- Manual trigger for filetypes not in auto_trigger_ft.
    vim.keymap.set('i', '<A-y>', function() require('minuet.virtualtext').action.next() end, { desc = 'Trigger FIM completion' })
  end,
}
