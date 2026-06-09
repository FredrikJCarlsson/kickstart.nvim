-- Rendering and application of next-edits.
-- A pending edit is shown as a virtual diff: the SEARCH lines are tinted
-- like a deletion and the REPLACE lines appear underneath as virt_lines,
-- with a hint in the corner. <Tab> applies it (see init.lua).

local M = {}

local ns = vim.api.nvim_create_namespace 'nextedit'

local rendered_bufs = {}

local function ensure_hl()
  vim.api.nvim_set_hl(0, 'NextEditOld', { default = true, link = 'DiffDelete' })
  vim.api.nvim_set_hl(0, 'NextEditNew', { default = true, link = 'DiffAdd' })
  vim.api.nvim_set_hl(0, 'NextEditHint', { default = true, link = 'Comment' })
end

--- Resolve an edit's path to a loaded buffer (loading the file if needed).
--- Returns bufnr or nil.
function M.resolve_buf(edit, fallback_bufnr)
  if not edit.path or edit.path == '' then return fallback_bufnr end
  local path = vim.fn.fnamemodify(edit.path, ':p')
  -- The model may echo a path for the current unnamed/equal buffer.
  if vim.fn.filereadable(path) == 0 then
    local cur = vim.api.nvim_buf_get_name(fallback_bufnr)
    if cur ~= '' and vim.fn.fnamemodify(cur, ':.') == edit.path then return fallback_bufnr end
    return nil
  end
  local bufnr = vim.fn.bufadd(path)
  if not vim.api.nvim_buf_is_loaded(bufnr) then vim.fn.bufload(bufnr) end
  return bufnr
end

--- Locate the SEARCH text in `bufnr`. Exact, whole-line, unique match
--- (per the prompt contract). Returns 1-based inclusive (start, end) lines.
function M.locate(bufnr, search)
  local needle = vim.split(search, '\n', { plain = true })
  if #needle == 0 then return nil end
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local found
  for i = 1, #lines - #needle + 1 do
    local ok = true
    for j = 1, #needle do
      if lines[i + j - 1] ~= needle[j] then
        ok = false
        break
      end
    end
    if ok then
      if found then return nil end -- ambiguous: refuse rather than guess
      found = i
    end
  end
  if not found then return nil end
  return found, found + #needle - 1
end

--- Render `edit` in its buffer. Returns the resolved location
--- { bufnr, start_line, end_line } or nil if it can't be placed.
function M.render(edit, fallback_bufnr, idx, total)
  ensure_hl()
  local bufnr = M.resolve_buf(edit, fallback_bufnr)
  if not bufnr then return nil end
  local start_line, end_line = M.locate(bufnr, edit.search)
  if not start_line then return nil end

  M.clear()
  rendered_bufs[bufnr] = true

  for l = start_line - 1, end_line - 1 do
    vim.api.nvim_buf_set_extmark(bufnr, ns, l, 0, { line_hl_group = 'NextEditOld' })
  end

  local virt_lines = {}
  for _, line in ipairs(vim.split(edit.replace, '\n', { plain = true })) do
    virt_lines[#virt_lines + 1] = { { line == '' and ' ' or line, 'NextEditNew' } }
  end
  vim.api.nvim_buf_set_extmark(bufnr, ns, end_line - 1, 0, { virt_lines = virt_lines })

  vim.api.nvim_buf_set_extmark(bufnr, ns, start_line - 1, 0, {
    virt_text = { { ('  ⇥ Tab: apply [%d/%d]'):format(idx, total), 'NextEditHint' } },
    virt_text_pos = 'eol',
  })

  return { bufnr = bufnr, start_line = start_line, end_line = end_line }
end

--- Apply `edit` at a previously resolved location.
function M.apply(loc, edit)
  local replace = vim.split(edit.replace, '\n', { plain = true })
  vim.api.nvim_buf_set_lines(loc.bufnr, loc.start_line - 1, loc.end_line, false, replace)
end

function M.clear()
  for bufnr in pairs(rendered_bufs) do
    if vim.api.nvim_buf_is_valid(bufnr) then vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1) end
  end
  rendered_bufs = {}
end

return M
