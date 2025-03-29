return {
  "ahmedkhalf/project.nvim",
  config = function()
    require("project_nvim").setup {
      silent_chdir = false,
      detection_methods = { "pattern" }
    }
  end
}
