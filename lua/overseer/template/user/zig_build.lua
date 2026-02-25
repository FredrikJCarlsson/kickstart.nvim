return {
  name = "Zig build",
  builder = function()
    return {
      cmd = { "zig" },
      args = { "build" },
      cwd = vim.fs.dirname(vim.fs.find({ "build.zig", ".git" }, { upward = true })[1]) or vim.fn.getcwd(),
      components = { { "on_output_quickfix", open = true }, "default" },
    }
  end,
  condition = {
    filetype = { "zig" },
  },
}
