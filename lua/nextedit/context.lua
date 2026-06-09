-- Builds the user-message payload (spec section 2) from editor state:
-- CURRENT_FILE with a <|cursor|> marker, RECENT_EDITS as a unified diff,
-- DIAGNOSTICS, and LSP REFERENCES for the symbol at the cursor.
-- Empty sections are dropped to save tokens.

local M = {}

-- Max lines of the current buffer to send. Whole file if it fits,
-- otherwise a window centered on the cursor.
local MAX_FILE_LINES = 400
local MAX_DIAGNOSTICS = 12
local MAX_REFERENCES = 10

local function relpath(path)
  return vim.fn.fnamemodify(path, ':.')
end

--- Current buffer text with the cursor position marked by <|cursor|>.
local function current_file_section(bufnr, win)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local row, col = unpack(vim.api.nvim_win_get_cursor(win))

  local first, last = 1, #lines
  if #lines > MAX_FILE_LINES then
    first = math.max(1, row - math.floor(MAX_FILE_LINES / 2))
    last = math.min(#lines, first + MAX_FILE_LINES - 1)
    first = math.max(1, last - MAX_FILE_LINES + 1)
  end

  local out = {}
  for i = first, last do
    local line = lines[i] or ''
    if i == row then line = line:sub(1, col) .. '<|cursor|>' .. line:sub(col + 1) end
    out[#out + 1] = line
  end

  local name = relpath(vim.api.nvim_buf_get_name(bufnr))
  if name == '' then name = '[No Name]' end
  return ('CURRENT_FILE: %s\n---\n%s\n---'):format(name, table.concat(out, '\n'))
end

--- Unified diff of the developer's recent edits (baseline -> now).
--- Returns nil when there is nothing to report.
function M.recent_edits_diff(bufnr, baseline_text)
  if not baseline_text then return nil end
  local current = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n') .. '\n'
  if current == baseline_text then return nil end
  local diff = vim.diff(baseline_text, current, { ctxlen = 1 })
  if not diff or diff == '' then return nil end
  local name = relpath(vim.api.nvim_buf_get_name(bufnr))
  return ('--- a/%s\n+++ b/%s\n%s'):format(name, name, diff)
end

local severity_label = {
  [vim.diagnostic.severity.ERROR] = 'error',
  [vim.diagnostic.severity.WARN] = 'warning',
  [vim.diagnostic.severity.INFO] = 'info',
  [vim.diagnostic.severity.HINT] = 'hint',
}

--- Errors/warnings across all loaded buffers, nearest-file first.
local function diagnostics_section(bufnr)
  local diags = vim.diagnostic.get(nil, { severity = { min = vim.diagnostic.severity.WARN } })
  table.sort(diags, function(a, b)
    if (a.bufnr == bufnr) ~= (b.bufnr == bufnr) then return a.bufnr == bufnr end
    return a.severity < b.severity
  end)
  local out = {}
  for _, d in ipairs(diags) do
    if #out >= MAX_DIAGNOSTICS then break end
    local name = vim.api.nvim_buf_get_name(d.bufnr or bufnr)
    if name ~= '' then
      local msg = (d.message or ''):gsub('\n.*', '')
      out[#out + 1] = ('%s:%d:%d: %s: %s'):format(relpath(name), d.lnum + 1, d.col + 1, severity_label[d.severity] or 'note', msg)
    end
  end
  if #out == 0 then return nil end
  return 'DIAGNOSTICS:\n' .. table.concat(out, '\n')
end

local function client_request(client, method, params, handler, bufnr)
  if vim.fn.has 'nvim-0.11' == 1 then return client:request(method, params, handler, bufnr) end
  return client.request(method, params, handler, bufnr)
end

local function snippet_for(path, lnum)
  local b = vim.fn.bufnr(path)
  if b ~= -1 and vim.api.nvim_buf_is_loaded(b) then
    return (vim.api.nvim_buf_get_lines(b, lnum - 1, lnum, false)[1] or ''):gsub('^%s+', '  ')
  end
  if vim.fn.filereadable(path) == 1 then
    local lines = vim.fn.readfile(path, '', lnum)
    return (lines[lnum] or ''):gsub('^%s+', '  ')
  end
  return ''
end

--- Asynchronously collect textDocument/references for the symbol at the
--- cursor. Calls cb(section_or_nil, symbol). Never blocks; gives up after
--- `timeout_ms` and proceeds without references.
function M.references_async(bufnr, win, timeout_ms, cb)
  local symbol = vim.fn.expand '<cword>'
  local clients = vim.lsp.get_clients { bufnr = bufnr, method = 'textDocument/references' }
  if symbol == '' or #clients == 0 then
    cb(nil, symbol)
    return
  end

  local done = false
  local remaining = #clients
  local locations = {}

  local function finish()
    if done then return end
    done = true
    local cur_name = vim.api.nvim_buf_get_name(bufnr)
    -- The window can close while we wait for the LSP; fall back gracefully.
    local cursor_row = vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_cursor(win)[1] or -100
    local out, seen = {}, {}
    for _, loc in ipairs(locations) do
      if #out >= MAX_REFERENCES then break end
      local uri = loc.uri or loc.targetUri
      local range = loc.range or loc.targetSelectionRange
      if uri and range then
        local path = vim.uri_to_fname(uri)
        local lnum = range.start.line + 1
        local key = path .. ':' .. lnum
        -- Skip the definition site in the current buffer; the model already
        -- sees it in CURRENT_FILE.
        if not seen[key] and not (path == cur_name and math.abs(lnum - cursor_row) <= 1) then
          seen[key] = true
          out[#out + 1] = ('%s:%d: %s'):format(relpath(path), lnum, snippet_for(path, lnum))
        end
      end
    end
    if #out == 0 then
      cb(nil, symbol)
    else
      cb(('REFERENCES (symbol: %s):\n%s'):format(symbol, table.concat(out, '\n')), symbol)
    end
  end

  for _, client in ipairs(clients) do
    local params = vim.lsp.util.make_position_params(win, client.offset_encoding)
    params.context = { includeDeclaration = false }
    client_request(client, 'textDocument/references', params, function(err, result)
      if not err and type(result) == 'table' then vim.list_extend(locations, result) end
      remaining = remaining - 1
      if remaining == 0 then finish() end
    end, bufnr)
  end

  vim.defer_fn(finish, timeout_ms)
end

--- Assemble the full payload. `recent_edits` and `references` may be nil.
function M.build(bufnr, win, recent_edits, references)
  local parts = { current_file_section(bufnr, win) }
  if recent_edits then parts[#parts + 1] = 'RECENT_EDITS:\n' .. recent_edits end
  local diags = diagnostics_section(bufnr)
  if diags then parts[#parts + 1] = diags end
  if references then parts[#parts + 1] = references end
  return table.concat(parts, '\n\n')
end

return M
