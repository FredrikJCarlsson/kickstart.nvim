return {
  name = "syncAndStartGdb",
  builder = function()
    local script_path = vim.fn.getcwd() .. "/syncAndStartGdb.sh"
    
    return {
      cmd = { "bash" },
      args = { script_path },
      name = "Sync and Start GDB Server",
      cwd = vim.fn.getcwd(),
      components = {
        { "on_output_quickfix", open = true },
        "default",
      },
    }
  end,
  condition = {
    filetype = { "cpp", "c" },
    callback = function()
      local script_path = vim.fn.getcwd() .. "/syncAndStartGdb.sh"
      return vim.fn.filereadable(script_path) == 1
    end,
  },
}

