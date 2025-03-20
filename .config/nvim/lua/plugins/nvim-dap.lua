return {
  "mfussenegger/nvim-dap",
  dependencies = {
    "suketa/nvim-dap-ruby",
  },
  config = function()
    local dap = require "dap"

    dap.adapters["pwa-node"] = {
      type = "server",
      host = "localhost",
      port = "${port}",
      executable = {
        command = "node",
        -- 💀 Make sure to update this path to point to your installation
        args = { os.getenv("HOME" .. ".local/bin/js-debug/src/dapDebugServer.js"), "${port}" },
      },
    }

    -- Launch chrome with --remote-debugging-port=9222,
    -- ex: /Applications/Chromium.app/Contents/MacOS/Chromium --remote-debugging-port=9222
    dap.adapters.chrome = {
      type = "executable",
      command = "node",
      args = { os.getenv("HOME" .. ".local/bin/vscode-chrome-debug/out/src/chromeDebug.js") },
    }

    dap.configurations.javascript = {
      {
        name = "Javascript Node (run current file)",
        type = "pwa-node",
        request = "launch",
        program = "${file}",
        cwd = "${workspaceFolder}",
      },
    }

    dap.configurations.javascriptreact = { -- change this to javascript if needed
      {
        name = "Javascript React (attach)",
        type = "chrome",
        request = "attach",
        program = "${file}",
        cwd = vim.fn.getcwd(),
        sourceMaps = true,
        protocol = "inspector",
        port = 9222,
        webRoot = "${workspaceFolder}",
      },
    }

    dap.configurations.typescriptreact = { -- change to typescript if needed
      {
        name = "Typescript React (attach)",
        type = "chrome",
        request = "attach",
        program = "${file}",
        cwd = vim.fn.getcwd(),
        sourceMaps = true,
        protocol = "inspector",
        port = 9222,
        webRoot = "${workspaceFolder}",
      },
    }

    require("dap-ruby").setup()
  end,
}
