-- Local AI tab-completion via Ollama (Cursor-style ghost text).
--
-- Requires a running Ollama with a FIM-capable model, e.g.:
--   ollama pull qwen2.5-coder:1.5b-base   (or :3b-base / :7b-base, stronger)
--   ollama serve   (or `brew services start ollama`)
--
-- IMPORTANT: use the *-base* model, NOT the instruct variant. The instruct
-- (chat-tuned) model ignores the FIM tokens and returns prose; the base model
-- does true fill-in-the-middle and returns raw code.
--
-- NOTE: This uses qwen2.5-coder for fill-in-the-middle completion. The separate
-- `sweepai/sweep-next-edit` model is a *next-edit* model (Cursor-NES style), a
-- different protocol that minuet's FIM provider does not speak — keep it for a
-- dedicated NES integration, not this tab-completion path.
--
-- This replaces Copilot as the <Tab> completion provider. Accept the whole
-- suggestion with <Tab>; partial accept / cycle via the <A-*> maps below.
return {
  'milanglacier/minuet-ai.nvim',
  dependencies = { 'nvim-lua/plenary.nvim' },
  event = 'InsertEnter',
  config = function()
    require('minuet').setup {
      -- Cloud completion via Google Gemini.
      provider = 'gemini',
      n_completions = 1,
      context_window = 512,

      provider_options = {
        gemini = {
          model = 'gemini-2.5-flash',
          stream = true,
          api_key = 'GEMINI_API_KEY',
          end_point = 'https://generativelanguage.googleapis.com/v1beta/models',
          optional = {
            generationConfig = {
              maxOutputTokens = 256,
              thinkingConfig = {
                -- Disable thinking for gemini 2.5 models
                thinkingBudget = 0,
                -- Disable thinking for gemini 3.x models
                -- thinkingLevel = 'minimal',
                -- Setting only one of the above options is sufficient.
              },
            },
            safetySettings = {
              {
                -- HARM_CATEGORY_HATE_SPEECH,
                -- HARM_CATEGORY_HARASSMENT
                -- HARM_CATEGORY_SEXUALLY_EXPLICIT
                category = 'HARM_CATEGORY_DANGEROUS_CONTENT',
                -- BLOCK_NONE
                threshold = 'BLOCK_ONLY_HIGH',
              },
            },
          },
        },
      },

      -- provider_options = {
      --   openai_fim_compatible = {
      --     -- Ollama ignores the key, but minuet requires a non-empty value;
      --     -- TERM is always set in a shell environment.
      --     api_key = 'TERM',
      --     name = 'Ollama',
      --     end_point = 'http://localhost:11434/v1/completions',
      --     model = 'qwen2.5-coder:1.5b-base',
      --     -- Stream partial results so ghost text can appear before the
      --     -- request_timeout window closes (matters for a local model).
      --     -- This is minuet's default; set explicitly for clarity.
      --     stream = true,
      --     optional = {
      --       max_tokens = 256,
      --       top_p = 0.9,
      --     },
      --     -- qwen2.5-coder FIM: wrap context in the model's fill-in-the-middle
      --     -- special tokens ourselves. Without this, Ollama/llama.cpp returns
      --     -- chatty prose instead of a raw code completion. `suffix = false`
      --     -- because llama.cpp's /v1/completions ignores the OpenAI `suffix`
      --     -- field, so we embed the after-cursor text in the prompt instead.
      --     template = {
      --       prompt = function(context_before_cursor, context_after_cursor)
      --         return '<|fim_prefix|>' .. context_before_cursor .. '<|fim_suffix|>' .. context_after_cursor .. '<|fim_middle|>'
      --       end,
      --       suffix = false,
      --     },
      --   },
      -- },

      virtualtext = {
        -- Auto-show ghost text in these filetypes (empty = manual trigger only).
        -- Add filetypes you want it always-on for, or leave manual via <A-y>.
        auto_trigger_ft = { 'c', 'cpp', 'lua', 'python', 'go', 'rust', 'cs', 'zig', 'javascript', 'typescript', 'tsx' },
        keymap = {
          -- Accept the whole suggestion. <Tab> is wired below with a fallback.
          accept = nil,
          accept_line = '<A-a>',
          accept_n_lines = '<A-z>',
          prev = '<A-[>',
          next = '<A-]>',
          dismiss = '<A-e>',
        },
      },
    }

    -- <Tab>: accept minuet ghost text if visible, otherwise a literal Tab.
    -- The nvim-cmp popup menu is NOT accepted by Tab — that's <CR>'s job
    -- (see cmp.lua). This keeps Tab purely for AI ghost text, Cursor-style.
    local minuet_vt = require 'minuet.virtualtext'
    vim.keymap.set('i', '<Tab>', function()
      if minuet_vt.action.is_visible() then
        minuet_vt.action.accept()
      else
        -- No ghost text: insert a literal tab. The cmp menu (if open) is
        -- confirmed with <CR>, not here, so we don't interfere with it.
        local keys = vim.api.nvim_replace_termcodes('<Tab>', true, false, true)
        vim.api.nvim_feedkeys(keys, 'n', false)
      end
    end, { desc = 'Accept Ollama ghost text or Tab', silent = true })

    -- Manual trigger for filetypes not in auto_trigger_ft.
    vim.keymap.set('i', '<A-y>', function() minuet_vt.action.next() end, { desc = 'Trigger Ollama completion' })
  end,
}
