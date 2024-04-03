
vim.opt.signcolumn = "yes" -- otherwise it bounces in and out, not strictly needed though
vim.api.nvim_create_autocmd("FileType", {
  pattern = "eruby",
  group = vim.api.nvim_create_augroup("ErbFormatter", { clear = true }), -- also this is not /needed/ but it's good practice 
  callback = function()
    vim.lsp.start {
      name = "erb-format",
      cmd = { "erb-format" },
    }
  end,
})
