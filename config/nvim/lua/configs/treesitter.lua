-- Treesitter configuration (nvim-treesitter v2).
--
-- Parser list only. v2's setup() accepts nothing but install_dir, so there is
-- no highlight option to pass it. Highlighting is started per buffer by
-- NvChad's FileType autocmd, which calls vim.treesitter.start().

return {
  install = {
    "vim", "lua", "vimdoc", "html", "css",
    "c", "cpp", "nix", "mlir", "llvm", "tablegen",
    "hlsl", "slang", "glsl", "cuda",
    "python", "rust", "go", "typescript", "javascript",
    "bash", "json", "toml", "yaml", "markdown", "markdown_inline",
  },
}
