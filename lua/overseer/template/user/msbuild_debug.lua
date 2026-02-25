return {
    name = "MSBuild PQSecure (Debug)",
    builder = function()
        return {
            cmd = { "msbuild" },
            args = {
                "PQSecure.sln",
                "/t:Restore,Build",
                "/p:Configuration=Debug",
            },
            cwd = "C:/GIT/PQSecure.NET/PQSecure",
            --cwd = vim.fs.dirname(vim.fs.find({ "PQSecure.sln", ".git" }, { upward = true })[1]) or vim.fn.getcwd(),
            components = { { "on_output_quickfix", open = true }, "default" },
        }
    end,
    condition = {
        filetype = { "cs", "sln" },
    },
}
