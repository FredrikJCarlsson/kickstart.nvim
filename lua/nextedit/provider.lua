-- Streaming HTTP providers for the smart path. Two wire formats:
--   * gemini            - Google generative language API (SSE)
--   * openai_compatible - any /chat/completions endpoint: DeepSeek,
--                         OpenRouter, Copilot/Zen proxies, etc. (SSE)
-- Thinking is disabled at the API level (Gemini thinkingBudget = 0; for
-- OpenAI-compatible endpoints, pick a non-reasoning model id in the config).
--
-- One request is in flight at a time; M.request cancels the previous one.
-- Cancellation on new keystrokes is the single biggest perceived-speed win.

local M = {}

local active ---@type vim.SystemObj|nil

function M.cancel()
  if active then
    pcall(active.kill, active, 9)
    active = nil
  end
end

--- Non-SSE error bodies (HTTP 4xx/5xx) arrive as plain JSON; curl still exits 0.
local function parse_api_error(raw)
  if not raw or raw:match '^%s*$' then return nil end
  raw = raw:gsub('\n__HTTP__:%d+$', '')
  if not raw:match '%S' then return nil end
  local ok, decoded = pcall(vim.json.decode, raw)
  if not ok or type(decoded) ~= 'table' then return nil end
  local err = decoded.error
  if type(err) ~= 'table' then return nil end
  local msg = err.message or err.status or vim.inspect(err)
  local code = err.code or decoded.code
  if code then return ('nextedit: API error %s: %s'):format(tostring(code), msg:sub(1, 300)) end
  return ('nextedit: %s'):format(msg:sub(1, 300))
end

--- Spawn curl, feed it `body`, and decode SSE `data:` lines as they arrive.
--- extract(json) -> text delta. Callbacks are scheduled onto the main loop.
local function curl_sse(url, headers, body, extract, on_delta, on_done)
  M.cancel()

  local args = {
    'curl',
    '-sS',
    '-N',
    '--no-buffer',
    '--max-time',
    '30',
    '-X',
    'POST',
    url,
    '-H',
    'Content-Type: application/json',
  }
  for _, h in ipairs(headers) do
    args[#args + 1] = '-H'
    args[#args + 1] = h
  end
  args[#args + 1] = '--data-binary'
  args[#args + 1] = '@-'
  args[#args + 1] = '--write-out'
  args[#args + 1] = '\n__HTTP__:%{http_code}'

  local pending = ''
  local chunks = {}
  local this_request

  this_request = vim.system(args, {
    stdin = body,
    stdout = function(_, chunk)
      if not chunk or this_request ~= active then return end
      pending = pending .. chunk
      local got_delta = false
      while true do
        local nl = pending:find('\n', 1, true)
        if not nl then break end
        local line = pending:sub(1, nl - 1):gsub('\r$', '')
        pending = pending:sub(nl + 1)
        local data = line:match '^data:%s*(.+)'
        if data and data ~= '[DONE]' then
          local ok, decoded = pcall(vim.json.decode, data)
          if ok then
            local delta = extract(decoded)
            if delta and delta ~= '' then
              chunks[#chunks + 1] = delta
              got_delta = true
            end
          end
        end
      end
      if got_delta then
        vim.schedule(function()
          if this_request == active then on_delta(table.concat(chunks)) end
        end)
      end
    end,
  }, function(res)
    vim.schedule(function()
      if this_request ~= active then return end -- cancelled or superseded
      active = nil
      local text = table.concat(chunks)

      local http_code = tonumber(pending:match('__HTTP__:(%d+)$'))
      local raw_body = pending:gsub('\n__HTTP__:%d+$', '')

      if text == '' then
        local api_err = parse_api_error(raw_body)
        if api_err then
          on_done(nil, api_err)
          return
        end
        if res.code ~= 0 then
          on_done(nil, ('nextedit: curl exited with code %d: %s'):format(res.code, (res.stderr or ''):sub(1, 200)))
          return
        end
        if http_code and http_code >= 400 then
          on_done(nil, ('nextedit: HTTP %d from API'):format(http_code))
          return
        end
      end

      on_done(text, nil)
    end)
  end)
  active = this_request
end

local function gemini_extract(decoded)
  local cand = decoded.candidates and decoded.candidates[1]
  local parts = cand and cand.content and cand.content.parts
  if not parts then return nil end
  local out = {}
  for _, p in ipairs(parts) do
    if type(p.text) == 'string' then out[#out + 1] = p.text end
  end
  return table.concat(out)
end

local function openai_extract(decoded)
  local choice = decoded.choices and decoded.choices[1]
  return choice and choice.delta and choice.delta.content or nil
end

--- opts: { provider, model, end_point, api_key (env var name), temperature,
---         max_tokens, optional }, system + messages from prompt.lua.
--- opts.optional is deep-merged into the request body for provider-specific
--- tuning (gemini safetySettings, openai top_p, ...).
function M.request(opts, system, messages, on_delta, on_done)
  local key = os.getenv(opts.api_key or '')
  if not key or key == '' then
    on_done(nil, ('nextedit: environment variable %s is not set'):format(opts.api_key or '?'))
    return
  end

  if opts.provider == 'gemini' then
    local contents = {}
    for _, m in ipairs(messages) do
      contents[#contents + 1] = {
        role = m.role == 'assistant' and 'model' or 'user',
        parts = { { text = m.content } },
      }
    end
    local body = {
      system_instruction = { parts = { { text = system } } },
      contents = contents,
      generationConfig = {
        temperature = opts.temperature,
        maxOutputTokens = opts.max_tokens,
        -- Disable thinking; latency matters more than deliberation here.
        thinkingConfig = { thinkingBudget = 0 },
      },
    }
    body = vim.tbl_deep_extend('force', body, opts.optional or {})
    local url = ('%s/%s:streamGenerateContent?alt=sse'):format(opts.end_point, opts.model)
    curl_sse(url, { 'x-goog-api-key: ' .. key }, vim.json.encode(body), gemini_extract, on_delta, on_done)
  elseif opts.provider == 'openai_compatible' then
    local msgs = { { role = 'system', content = system } }
    vim.list_extend(msgs, messages)
    local body = {
      model = opts.model,
      messages = msgs,
      temperature = opts.temperature,
      max_tokens = opts.max_tokens,
      stream = true,
    }
    body = vim.tbl_deep_extend('force', body, opts.optional or {})
    curl_sse(opts.end_point, { 'Authorization: Bearer ' .. key }, vim.json.encode(body), openai_extract, on_delta, on_done)
  else
    on_done(nil, 'nextedit: unknown provider ' .. tostring(opts.provider))
  end
end

return M
