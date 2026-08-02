-- Editor options and small UX autocommands.

require "nvchad.options"

local api = vim.api
local fn = vim.fn
local opt = vim.opt
local uv = vim.uv

local backupdir = fn.stdpath "data" .. "/backup"
local undodir = fn.stdpath "data" .. "/undotree"

fn.mkdir(backupdir, "p")
fn.mkdir(undodir, "p")

opt.foldmethod = "expr"
opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
opt.foldenable = false
opt.relativenumber = true

opt.backup = true
opt.writebackup = true
opt.backupdir = backupdir

opt.undofile = true
opt.undodir = undodir

local large_file_group = api.nvim_create_augroup("UserLargeFile", { clear = true })
local large_file_threshold = 2 * 1024 * 1024

local function is_large_file(bufnr)
  if vim.b[bufnr].large_file then
    return true
  end

  local name = api.nvim_buf_get_name(bufnr)
  if name == "" then
    return false
  end

  local stat = uv.fs_stat(name)
  return stat ~= nil and stat.size > large_file_threshold
end

local function apply_large_file_window_options(bufnr)
  for _, winid in ipairs(api.nvim_list_wins()) do
    if api.nvim_win_get_buf(winid) == bufnr then
      api.nvim_set_option_value("foldmethod", "manual", { win = winid })
      api.nvim_set_option_value("foldexpr", "0", { win = winid })
      api.nvim_set_option_value("relativenumber", false, { win = winid })
    end
  end
end

local function apply_large_file_options(bufnr)
  if not api.nvim_buf_is_valid(bufnr) then
    return
  end

  vim.b[bufnr].large_file = true

  pcall(vim.treesitter.stop, bufnr)
  vim.bo[bufnr].syntax = ""
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].undofile = false
  apply_large_file_window_options(bufnr)

  pcall(function()
    require("gitsigns").detach(bufnr)
  end)

  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    vim.lsp.buf_detach_client(bufnr, client.id)
  end
end

api.nvim_create_autocmd({ "BufReadPre", "FileType", "BufWinEnter" }, {
  group = large_file_group,
  callback = function(args)
    if not is_large_file(args.buf) then
      return
    end

    apply_large_file_options(args.buf)

    vim.schedule(function()
      apply_large_file_options(args.buf)
    end)
  end,
})

local filetype_group = api.nvim_create_augroup("UserFiletypes", { clear = true })
api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
  group = filetype_group,
  pattern = "*.mlir",
  callback = function()
    -- Some MLIR files do not get detected correctly by default.
    vim.bo.filetype = "mlir"
  end,
})

-- Neovim ships no extension mapping for HLSL, so shader sources open with an
-- empty filetype and get neither treesitter nor LSP. Cover the Direct3D,
-- effect-file, and Unreal spellings. Slang needs nothing here: .slang already
-- maps to shaderslang upstream.
vim.filetype.add {
  extension = {
    hlsl = "hlsl",
    hlsli = "hlsl",
    fx = "hlsl",
    fxh = "hlsl",
    usf = "hlsl",
    ush = "hlsl",
  },
}

opt.clipboard = ""

local view_state = {}
local view_group = api.nvim_create_augroup("UserViewState", { clear = true })

api.nvim_create_autocmd("BufLeave", {
  group = view_group,
  callback = function()
    -- Remember the current window view per buffer when jumping between files.
    local bufnr = api.nvim_get_current_buf()
    view_state[bufnr] = fn.winsaveview()
  end,
})

api.nvim_create_autocmd("BufEnter", {
  group = view_group,
  callback = function()
    local bufnr = api.nvim_get_current_buf()
    if view_state[bufnr] then
      -- Restore cursor/scroll position when re-entering the buffer.
      fn.winrestview(view_state[bufnr])
    end
  end,
})
