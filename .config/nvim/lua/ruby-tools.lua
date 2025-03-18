return {
  setup = function()
    -- vim.lsp.commands["rubyLsp.runTest"] = function()
    --     require("neotest").run.run()
    -- end
    --
    -- vim.lsp.commands["rubyLsp.runTestInTerminal"] = function()
    --     require("neotest").run.run()
    -- end
    --
    -- vim.lsp.commands["rubyLsp.debugTest"] = function()
    --     require("neotest").run.run { strategy = "dap", suite = false }
    -- end
    --
    -- vim.lsp.commands["rubyLsp.openFile"] = function(args)
    --     local filearg = args.arguments[1][1]:gsub("file:///", "/")
    --     local parts = vim.split(filearg, "#L")
    --     local file = parts[1]
    --     local line = parts[2]
    --
    --     if line == nil then
    --         vim.cmd.edit(file)
    --     else
    --         vim.cmd("e " .. "+" .. line .. " " .. file)
    --     end
    -- end
  end
}
