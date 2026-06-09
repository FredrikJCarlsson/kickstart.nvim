-- Central configuration for nextedit: defaults + user-override merging.
-- Users configure everything from one place - see
-- lua/custom/plugins/nextedit.lua for a fully documented example covering
-- all providers, context sizing, and keybindings.

local M = {}

M.defaults = {
  -- Start with auto-trigger on (:NextEditToggle flips it at runtime).
  enabled = true,

  ------------------------------------------------------------------ provider
  -- 'gemini' or 'openai_compatible'. DeepSeek, OpenRouter, Copilot/Zen
  -- proxies, and local Ollama instruct models all speak the
  -- openai_compatible /chat/completions dialect.
  provider = 'gemini',
  model = 'gemini-3.5-flash',
  -- gemini: base URL (model name is appended). openai_compatible: the FULL
  -- /chat/completions URL.
  end_point = 'https://generativelanguage.googleapis.com/v1beta/models',
  -- NAME of the environment variable holding the key (never the key itself).
  api_key = 'GEMINI_API_KEY',
  temperature = 0.1,
  max_tokens = 512,
  -- Extra fields deep-merged into the request body, for provider-specific
  -- tuning (e.g. gemini safetySettings, openai top_p). See the example
  -- config file.
  optional = {},

  ------------------------------------------------------------------ behavior
  -- Predict automatically on InsertLeave / normal-mode changes; manual
  -- trigger (keymap / :NextEdit) always works.
  auto_trigger = true,
  -- Wait this long after the last change before firing; new keystrokes
  -- cancel in-flight requests.
  debounce_ms = 400,
  -- Filetypes where auto-trigger is active (manual trigger ignores this).
  filetypes = { 'c', 'cpp', 'lua', 'python', 'go', 'rust', 'cs', 'zig', 'javascript', 'typescript', 'typescriptreact', 'tsx' },

  ------------------------------------------------------------------- context
  context = {
    -- Max lines of the current buffer sent as CURRENT_FILE. Whole file if it
    -- fits, otherwise a window centered on the cursor.
    max_file_lines = 400,
    -- Max LSP diagnostics / reference sites included in the payload.
    max_diagnostics = 12,
    max_references = 10,
    -- How long to wait for textDocument/references before proceeding
    -- without it.
    lsp_timeout_ms = 400,
    -- If the recent-edits diff grows beyond this many lines the baseline is
    -- considered stale and re-anchored instead of being sent.
    max_diff_lines = 120,
  },

  ------------------------------------------------------------------- keymaps
  -- Set any of these to false to skip the mapping and wire your own against
  -- the public API (require('nextedit').accept() / trigger() / dismiss()).
  keymap = {
    -- Insert mode: minuet ghost text > pending next-edit > literal key.
    -- Normal mode: apply pending next-edit and jump to the next one;
    -- falls back to <C-i> (jumplist) when nothing is pending.
    accept = '<Tab>',
    -- Force a prediction now (insert + normal mode).
    trigger = '<A-n>',
    -- Throw away the pending run (normal mode).
    dismiss = '<A-e>',
  },
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend('force', vim.deepcopy(M.defaults), opts or {})
  return M.options
end

return M
