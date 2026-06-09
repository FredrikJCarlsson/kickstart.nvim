-- Incremental parser for the model's <edit> SEARCH/REPLACE blocks.
-- Designed to be re-run on a growing streamed buffer: it only returns
-- blocks that are fully closed, so edits can be rendered as they complete.

local M = {}

local SEARCH_MARK = '<<<<<<< SEARCH\n'
local SEP_MARK = '\n=======\n'
local REPLACE_MARK = '\n>>>>>>> REPLACE'
local CLOSE_TAG = '</edit>'
local MAX_BLOCKS = 5

--- Parse all complete edit blocks out of `text`.
--- Returns a list of { path = string|nil, search = string, replace = string }.
function M.parse(text)
  local edits = {}
  local pos = 1
  while #edits < MAX_BLOCKS do
    local open = text:find('<edit', pos, true)
    if not open then break end
    local tag_end = text:find('>', open, true)
    if not tag_end then break end
    local path = text:sub(open, tag_end):match 'path%s*=%s*"([^"]*)"'

    local search_at = text:find(SEARCH_MARK, tag_end + 1, true)
    if not search_at then break end
    local sep_at = text:find(SEP_MARK, search_at + #SEARCH_MARK, true)
    if not sep_at then break end
    local replace_at = text:find(REPLACE_MARK, sep_at + #SEP_MARK - 1, true)
    if not replace_at then break end
    local close_at = text:find(CLOSE_TAG, replace_at + #REPLACE_MARK, true)
    if not close_at then break end

    edits[#edits + 1] = {
      path = path,
      search = text:sub(search_at + #SEARCH_MARK, sep_at - 1),
      replace = text:sub(sep_at + #SEP_MARK, replace_at - 1),
    }
    pos = close_at + #CLOSE_TAG
  end
  return edits
end

--- True once the (possibly partial) response is committed to NO_EDIT.
function M.is_no_edit(text)
  return text:match '^%s*NO_EDIT' ~= nil
end

return M
