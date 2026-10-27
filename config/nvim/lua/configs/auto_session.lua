-- auto-session configuration.

local home = vim.fn.expand "~"

return {
  auto_save = true,
  -- `nvim` with no file arguments reopens the last session for this folder
  -- (home included); `nvim somefile` opens just that file.
  auto_restore = true,
  -- Also save on exit when started as `nvim somefile` (the usual way here);
  -- that replaces the folder's session with what was open at exit.
  args_allow_files_auto_save = true,
  suppressed_dirs = {
    home .. "/Downloads",
    "/",
  },
  session_lens = {
    picker = "telescope",
    load_on_setup = false,
  },
}
