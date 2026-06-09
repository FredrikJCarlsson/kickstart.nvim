-- Smart-path next-edit prediction (Cursor Tab-style), implemented locally in
-- lua/nextedit/. This file is the CONFIG FILE: every available option is
-- shown below with its default, plus ready-to-paste examples for all
-- supported providers. Uncomment one provider block at a time.
--
-- Defaults live in lua/nextedit/config.lua; anything omitted here keeps its
-- default value.

return {
  {
    name = 'nextedit',
    dir = vim.fn.stdpath 'config' .. '/lua/nextedit',
    event = 'VeryLazy',
    config = function()
      require('nextedit').setup {

        -------------------------------------------------------------------
        -- PROVIDER
        --
        -- Two wire formats are supported:
        --   * 'gemini'            - Google generative language API
        --   * 'openai_compatible' - any /chat/completions endpoint
        -- `api_key` is the NAME of the environment variable holding the key,
        -- never the key itself. Pick a non-reasoning model and keep thinking
        -- off - latency beats deliberation for tab completion.
        -------------------------------------------------------------------

        -- (1) Google Gemini Flash (active default; thinking disabled
        --     internally via thinkingBudget = 0):
        provider = 'gemini',
        model = 'gemini-2.5-flash',
        end_point = 'https://generativelanguage.googleapis.com/v1beta/models',
        api_key = 'GEMINI_API_KEY',

        -- (2) DeepSeek (use the non-reasoning chat model, NOT deepseek-reasoner):
        -- provider = 'openai_compatible',
        -- model = 'deepseek-chat',
        -- end_point = 'https://api.deepseek.com/chat/completions',
        -- api_key = 'DEEPSEEK_API_KEY',

        -- (3) OpenRouter (any non-reasoning model id on the router):
        -- provider = 'openai_compatible',
        -- model = 'google/gemini-2.5-flash',          -- or 'deepseek/deepseek-chat', ...
        -- end_point = 'https://openrouter.ai/api/v1/chat/completions',
        -- api_key = 'OPENROUTER_API_KEY',

        -- (4) GitHub Copilot / Zen, via a local OpenAI-compatible proxy
        --     (e.g. `copilot-api` or an opencode/zen gateway). Point at
        --     wherever the proxy listens:
        -- provider = 'openai_compatible',
        -- model = 'gpt-4o-mini',
        -- end_point = 'http://localhost:4141/v1/chat/completions',
        -- api_key = 'COPILOT_PROXY_KEY',

        -- (5) Fully local via Ollama (an INSTRUCT model this time - unlike
        --     the FIM fast path, the smart path needs a chat model). Slower
        --     but free and offline. Ollama ignores the key; TERM is just a
        --     non-empty env var that always exists:
        -- provider = 'openai_compatible',
        -- model = 'qwen2.5-coder:7b-instruct',
        -- end_point = 'http://localhost:11434/v1/chat/completions',
        -- api_key = 'TERM',

        -- Sampling (spec: 0.0-0.2 and a hard token cap):
        temperature = 0.1,
        max_tokens = 512,

        -- Extra fields deep-merged into the request body, for
        -- provider-specific knobs the options above don't cover, e.g.:
        -- optional = {
        --   -- gemini:
        --   safetySettings = { { category = 'HARM_CATEGORY_DANGEROUS_CONTENT', threshold = 'BLOCK_ONLY_HIGH' } },
        --   -- openai_compatible:
        --   -- top_p = 0.9,
        -- },

        -------------------------------------------------------------------
        -- BEHAVIOR
        -------------------------------------------------------------------

        -- Master switch for auto-trigger at startup (:NextEditToggle flips
        -- it at runtime; manual trigger always works).
        enabled = true,
        -- Predict automatically on InsertLeave / normal-mode edits.
        auto_trigger = true,
        -- Quiet period after the last change before a request fires; typing
        -- again cancels the in-flight request.
        debounce_ms = 400,
        -- Filetypes where auto-trigger is active (manual trigger ignores this):
        -- filetypes = { 'c', 'cpp', 'lua', 'python', 'go', 'rust', 'cs', 'zig', 'javascript', 'typescript', 'typescriptreact', 'tsx' },

        -------------------------------------------------------------------
        -- CONTEXT SIZE - what gets sent to the model per request
        -------------------------------------------------------------------

        context = {
          -- Lines of the current buffer (whole file if it fits, else a
          -- window centered on the cursor). Raise for more context, lower
          -- for cheaper/faster requests.
          max_file_lines = 400,
          -- LSP signals included in the payload:
          max_diagnostics = 12,
          max_references = 10,
          -- How long to wait for textDocument/references before sending the
          -- request without them:
          lsp_timeout_ms = 400,
          -- Recent-edit diffs larger than this are considered stale and the
          -- baseline is re-anchored instead:
          max_diff_lines = 120,
        },

        -------------------------------------------------------------------
        -- KEYBINDINGS
        --
        -- Set any entry to false to skip it and wire your own mapping
        -- against the public API: require('nextedit').accept() -> bool,
        -- .trigger { manual = true }, .dismiss(), .is_pending() -> bool.
        -------------------------------------------------------------------

        keymap = {
          -- Insert mode: minuet ghost text (if enabled) > pending next-edit
          -- > literal key. Normal mode: apply the pending edit and jump to
          -- the next one ("Tab to jump"); <Tab> falls back to the jumplist.
          accept = '<Tab>',
          -- Force a prediction now (insert + normal mode):
          trigger = '<A-n>',
          -- Throw away the pending run (normal mode):
          dismiss = '<A-e>',
        },
      }
    end,
  },
}
