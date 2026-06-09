-- nextedit: Cursor-style next-edit prediction for Neovim (the "smart path").
--
-- Two-tier design (see lua/custom/plugins/minuet.lua for the fast path):
--   * Fast path  - local FIM model via minuet for inline ghost text.
--   * Smart path - THIS module. An instruct model receives the current
--     buffer, the developer's recent edits (unified diff), LSP diagnostics
--     and references, and predicts structured SEARCH/REPLACE edits -
--     including cross-file propagation of renames / signature changes.
--
-- Flow per trigger:
--   1. Detect recent symbol-affecting changes (buffer baseline -> diff).
--   2. Query the LSP for textDocument/references at the cursor.
--   3. Build the context payload and stream a request to the model
--      (cancelling any in-flight request first).
--   4. Parse <edit> blocks incrementally as they stream in.
--   5. Render the nearest edit as a virtual diff; <Tab> applies it and
--      jumps to the next pending edit ("Tab to jump"). Repeat until done.
--
-- Public API: setup(opts), trigger(), accept() -> bool, dismiss(),
-- is_pending() -> bool, toggle().
--
-- All options (providers, context sizing, keybindings) live in
-- nextedit/config.lua; see lua/custom/plugins/nextedit.lua for a fully
-- documented example configuration.

local config_mod = require 'nextedit.config'
local context = require 'nextedit.context'
local parser = require 'nextedit.parser'
local prompt = require 'nextedit.prompt'
local provider = require 'nextedit.provider'
local ui = require 'nextedit.ui'

local M = {}

local config = config_mod.options

local state = {
  enabled = true,
  generation = 0, -- bumped to invalidate stale async callbacks
  baseline = {}, -- bufnr -> buffer text snapshot ("recent edits" anchor)
  pending = nil, -- list of parsed edits for the active run
  idx = 0, -- index of the edit currently rendered
  loc = nil, -- resolved { bufnr, start_line, end_line } of the rendered edit
  origin_buf = nil, -- buffer the run was triggered from
  touched = {}, -- buffers modified by accept(), for baseline rotation
  applying = false, -- suppress TextChanged invalidation for our own writes
  timer = nil,
  cache = {}, -- payload sha -> parsed edits
  cache_size = 0,
}

local function buf_text(bufnr)
  return table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n') .. '\n'
end

local function rotate_baseline(bufnr)
  if vim.api.nvim_buf_is_valid(bufnr) then state.baseline[bufnr] = buf_text(bufnr) end
end

local function reset_run(opts)
  state.generation = state.generation + 1
  provider.cancel()
  ui.clear()
  if (opts or {}).rotate then
    for bufnr in pairs(state.touched) do
      rotate_baseline(bufnr)
    end
  end
  state.pending, state.idx, state.loc, state.origin_buf, state.touched = nil, 0, nil, nil, {}
end

function M.is_pending()
  return state.pending ~= nil and state.idx >= 1 and state.idx <= #state.pending
end

function M.dismiss()
  reset_run()
end

--- Render edit `idx` of the active run; skips edits whose SEARCH text can
--- no longer be located (stale or hallucinated). Returns true if something
--- is on screen.
local function show(idx)
  local pending = state.pending
  while pending and idx <= #pending do
    local loc = ui.render(pending[idx], state.origin_buf, idx, #pending)
    if loc then
      state.idx, state.loc = idx, loc
      return true
    end
    idx = idx + 1
  end
  reset_run { rotate = true }
  return false
end

--- Apply the rendered edit and jump to the next pending one.
function M.accept()
  if not M.is_pending() or not state.loc then return false end
  local edit = state.pending[state.idx]
  local loc = state.loc

  -- Locations can drift while a run is pending; re-resolve before writing.
  local start_line, end_line = ui.locate(loc.bufnr, edit.search)
  if start_line then
    state.applying = true
    ui.apply({ bufnr = loc.bufnr, start_line = start_line, end_line = end_line }, edit)
    state.touched[loc.bufnr] = true
    vim.schedule(function() state.applying = false end)
  end

  local next_idx = state.idx + 1
  ui.clear()
  if not state.pending or next_idx > #state.pending then
    reset_run { rotate = true }
    return true
  end
  if show(next_idx) and state.loc then
    -- "Tab to jump": move the cursor to the next pending edit.
    if vim.api.nvim_get_current_buf() ~= state.loc.bufnr then vim.api.nvim_set_current_buf(state.loc.bufnr) end
    pcall(vim.api.nvim_win_set_cursor, 0, { state.loc.start_line, 0 })
  end
  return true
end

local function cache_get(key)
  return state.cache[key]
end

local function cache_put(key, edits)
  if state.cache_size > 50 then
    state.cache, state.cache_size = {}, 0
  end
  if not state.cache[key] then state.cache_size = state.cache_size + 1 end
  state.cache[key] = edits
end

local function start_run(bufnr, edits, run_opts)
  run_opts = run_opts or {}
  state.pending = edits
  state.origin_buf = bufnr
  state.touched = {}
  if not show(1) and run_opts.manual then
    vim.notify('nextedit: predicted edits could not be located in buffer', vim.log.levels.WARN)
  end
end

--- Fire a smart-path request. opts.manual bypasses the auto-trigger gates.
function M.trigger(opts)
  opts = opts or {}
  if not state.enabled and not opts.manual then return end

  local bufnr = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()
  if vim.bo[bufnr].buftype ~= '' then return end
  if not opts.manual and not vim.tbl_contains(config.filetypes, vim.bo[bufnr].filetype) then return end

  local recent = context.recent_edits_diff(bufnr, state.baseline[bufnr])
  -- Without a recent edit there is nothing to propagate; stay quiet unless
  -- the user asked explicitly.
  if not recent and not opts.manual then return end
  -- A huge diff means the baseline is stale; re-anchor instead of sending it.
  if recent and #vim.split(recent, '\n') > config.context.max_diff_lines then
    rotate_baseline(bufnr)
    recent = nil
    if not opts.manual then return end
  end

  reset_run()
  local generation = state.generation

  context.references_async(bufnr, win, config.context.lsp_timeout_ms, function(references)
    if generation ~= state.generation or not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_win_is_valid(win) then return end

    local payload = context.build(bufnr, win, recent, references)
    -- Cache on the exact payload: file content + cursor + recent edits +
    -- diagnostics. Identical context never re-requests.
    local key = vim.fn.sha256(payload)
    -- Manual trigger always re-requests; cached empty results used to fail silently.
    if not opts.manual then
      local cached = cache_get(key)
      if cached then
        if #cached > 0 then start_run(bufnr, cached) end
        return
      end
    end

    local run_opts = { manual = opts.manual }
    local rendered = false
    provider.request(config, prompt.system, prompt.messages(payload), function(text)
      -- Streaming: render edits as blocks complete.
      if generation ~= state.generation then return end
      if parser.is_no_edit(text) then return end
      local edits = parser.parse(text)
      if #edits == 0 then return end
      if not rendered then
        rendered = true
        start_run(bufnr, edits, run_opts)
      else
        state.pending = edits -- later blocks extend the queue
      end
    end, function(text, err)
      if err then
        if opts.manual then vim.notify(err, vim.log.levels.WARN) end
        return
      end
      if generation ~= state.generation then return end
      if text == nil then return end
      local edits = parser.is_no_edit(text) and {} or parser.parse(text)
      if not opts.manual then cache_put(key, edits) end
      if #edits == 0 then
        if opts.manual then vim.notify('nextedit: no edit predicted', vim.log.levels.INFO) end
        reset_run()
        return
      end
      if not rendered then
        start_run(bufnr, edits, run_opts)
      else
        state.pending = edits
      end
    end)
  end)
end

function M.toggle()
  state.enabled = not state.enabled
  if not state.enabled then reset_run() end
  vim.notify('nextedit: auto-trigger ' .. (state.enabled and 'enabled' or 'disabled'))
end

local function debounced_trigger()
  if state.timer then
    state.timer:stop()
    state.timer:close()
  end
  state.timer = vim.uv.new_timer()
  state.timer:start(config.debounce_ms, 0, function()
    state.timer:close()
    state.timer = nil
    vim.schedule(function() M.trigger {} end)
  end)
end

--- Keymaps are driven by config.keymap; set an entry to false and wire your
--- own mapping against the public API instead.
local function setup_keymaps()
  local km = config.keymap or {}

  if km.accept then
    -- Insert mode: fast path first (minuet ghost text, if installed), then
    -- the smart path (pending next-edit), then the literal key. The nvim-cmp
    -- popup is confirmed with <CR> (see cmp.lua), never with Tab.
    vim.keymap.set('i', km.accept, function()
      local ok, minuet_vt = pcall(require, 'minuet.virtualtext')
      if ok and minuet_vt.action.is_visible() then
        minuet_vt.action.accept()
      elseif M.is_pending() then
        M.accept()
      else
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(km.accept, true, false, true), 'n', false)
      end
    end, { desc = 'Accept ghost text / next-edit, or fall through', silent = true })

    -- Normal mode: apply the pending next-edit and jump to the next one
    -- ("Tab to jump"). <Tab> falls back to its default jumplist motion.
    vim.keymap.set('n', km.accept, function()
      if not M.accept() then
        local fallback = km.accept:lower() == '<tab>' and '<C-i>' or km.accept
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(fallback, true, false, true), 'n', false)
      end
    end, { desc = 'Apply next-edit or fall through', silent = true })
  end

  if km.trigger then
    vim.keymap.set({ 'n', 'i' }, km.trigger, function() M.trigger { manual = true } end, { desc = 'Predict next edit' })
  end
  if km.dismiss then vim.keymap.set('n', km.dismiss, M.dismiss, { desc = 'Dismiss next-edit' }) end
end

function M.setup(opts)
  config = config_mod.setup(opts)
  state.enabled = config.enabled

  local group = vim.api.nvim_create_augroup('nextedit', { clear = true })

  -- Anchor the "recent edits" baseline the first time we see a buffer.
  vim.api.nvim_create_autocmd({ 'BufEnter', 'InsertEnter' }, {
    group = group,
    callback = function(ev)
      if vim.bo[ev.buf].buftype == '' and not state.baseline[ev.buf] then state.baseline[ev.buf] = buf_text(ev.buf) end
    end,
  })

  vim.api.nvim_create_autocmd('BufDelete', {
    group = group,
    callback = function(ev) state.baseline[ev.buf] = nil end,
  })

  -- The user typing invalidates the pending run and cancels any in-flight
  -- request (debounce + cancel is the biggest perceived-speed win).
  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
    group = group,
    callback = function()
      if state.applying then return end
      if M.is_pending() then reset_run() else provider.cancel() end
      if config.auto_trigger and vim.api.nvim_get_mode().mode == 'n' then debounced_trigger() end
    end,
  })

  if config.auto_trigger then
    vim.api.nvim_create_autocmd('InsertLeave', {
      group = group,
      callback = debounced_trigger,
    })
  end

  vim.api.nvim_create_user_command('NextEdit', function() M.trigger { manual = true } end, { desc = 'Predict next edit (smart path)' })
  vim.api.nvim_create_user_command('NextEditToggle', M.toggle, { desc = 'Toggle next-edit auto-trigger' })

  setup_keymaps()
end

return M
