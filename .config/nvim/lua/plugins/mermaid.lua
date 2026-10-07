-- mermaid.nvim: formatting, linting (via mmdc), and live browser preview for .mmd/.mermaid files
-- https://github.com/kevalin/mermaid.nvim
--
-- Pinned to a reviewed commit. Note: :MermaidPreview binds its HTTP server to 0.0.0.0,
-- so the current diagram is readable by anyone on your network while the preview runs
-- (it auto-stops ~20s after the browser tab closes). Avoid it on untrusted networks.
return {
  "kevalin/mermaid.nvim",
  commit = "4da12693b3b4d63b67d07bafe8340b4abc265c70",
  ft = "mermaid",
  cmd = { "MermaidFormat", "MermaidPreview", "MermaidPreviewStop", "MermaidCopyURL", "MermaidRender" },
  opts = {},
}
