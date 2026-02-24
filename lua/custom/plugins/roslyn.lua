return {
  'seblj/roslyn.nvim',
  ft = 'cs',
  opts = {
    config = {
      settings = {
        ['csharp|background_analysis'] = {
          dotnet_analyzer_diagnostics_scope = 'fullSolution',
          dotnet_compiler_diagnostics_scope = 'fullSolution',
        },
        ['csharp|completion'] = {
          dotnet_provide_regex_completions = true,
          dotnet_show_completion_items_from_unimported_namespaces = true,
          dotnet_show_name_completion_suggestions = true,
        },
        ['csharp|inlay_hints'] = {
          csharp_enable_inlay_hints_for_implicit_object_creation = true,
          csharp_enable_inlay_hints_for_implicit_variable_types = true,
          csharp_enable_inlay_hints_for_lambda_parameter_types = true,
          csharp_enable_inlay_hints_for_types = true,
          dotnet_enable_inlay_hints_for_indexer_parameters = true,
          dotnet_enable_inlay_hints_for_literal_parameters = true,
          dotnet_enable_inlay_hints_for_object_creation_parameters = true,
          dotnet_enable_inlay_hints_for_other_parameters = true,
          dotnet_enable_inlay_hints_for_parameters = true,
          dotnet_suppress_inlay_hints_for_parameters_that_differ_only_by_suffix = true,
          dotnet_suppress_inlay_hints_for_parameters_that_match_argument_name = true,
          dotnet_suppress_inlay_hints_for_parameters_that_match_method_intent = true,
        },
        ['csharp|code_lens'] = {
          dotnet_enable_references_code_lens = true,
        },
      },
    },
    -- "auto" | "roslyn" | "off"
    --
    -- - "auto": Does nothing for filewatching, leaving everything as default
    -- - "roslyn": Turns off neovim filewatching which will make roslyn do the filewatching
    -- - "off": Hack to turn off all filewatching. (Can be used if you notice performance issues)
    filewatching = 'roslyn',

    -- Optional function that takes an array of targets as the only argument. Return the target you
    -- want to use. If it returns `nil`, then it falls back to guessing the target like normal
    -- choose_target = function()
    --     vim.print("Choose target called")
    --
    --     -- Get the Git root
    --     local git_root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
    --     if not git_root or git_root == "" then
    --         vim.notify("Not inside a Git repository", vim.log.levels.ERROR)
    --         return nil
    --     end
    --     vim.print("Git root: " .. git_root)
    --
    --     -- Require plenary
    --     local scan = require("plenary.scandir")
    --
    --     -- Scan for all .sln files
    --     local files = scan.scan_dir(git_root, {
    --         depth = 5,
    --         add_dirs = false,
    --         search_pattern = "%.sln$", -- Search for .sln files
    --     })
    --
    --     for _, file in ipairs(files) do
    --         vim.print("Found solution: " .. file)
    --     end
    --
    --     -- Find and return the first .sln file
    --     local match = vim.iter(files):find(function(file)
    --         return true -- just pick the first one, or modify if you want user choice
    --     end)
    --
    --     if match then
    --         vim.print("Selected solution: " .. match)
    --     else
    --         vim.notify("No solution file found", vim.log.levels.WARN)
    --     end
    --
    --     return match
    -- end,
    choose_target = nil,

    -- Optional function that takes the selected target as the only argument.
    -- Returns a boolean of whether it should be ignored to attach to or not
    --
    -- I am for example using this to disable a solution with a lot of .NET Framework code on mac
    -- Example:
    --
    -- ignore_target = function(target)
    --     return string.match(target, "Foo.sln") ~= nil
    -- end
    ignore_target = nil,

    -- Whether or not to look for solution files in the child of the (root).
    -- Set this to true if you have some projects that are not a child of the
    -- directory with the solution file
    broad_search = true,

    -- Whether or not to lock the solution target after the first attach.
    -- This will always attach to the target in `vim.g.roslyn_nvim_selected_solution`.
    -- NOTE: You can use `:Roslyn target` to change the target
    lock_target = false,
  },
  -- config = function()
  --   -- Disable autoformat on save for C# buffers
  --   vim.api.nvim_create_autocmd("FileType", {
  --     pattern = "cs",
  --     callback = function()
  --       vim.b.autoformat = false
  --     end,
  --   })
  -- end,
}
