-- Notepad++-style auto-save, plus automatic recovery from swap files.
--
-- Auto-save: a changed file is written 3 s after the last edit (also in
-- Insert mode), when you switch to another buffer, when Neovim loses focus,
-- and on quit (QuitPre, so :q/:qa never stop at "No write since last
-- change"). Undo history survives writes (undofile), so `u` still works.
-- Only real files are saved: no unnamed buffers, help, terminals, read-only
-- or nonexistent-folder files, nor files over 1 MB (each save rewrites the
-- whole file; a one-time notice says to use :w). A file changed on disk by
-- another program since we read it is not overwritten (we warn instead;
-- `:e!` reloads it, `:w!` overwrites it).
--
-- Swap recovery: after a crash or reboot, a swap file with unsaved edits
-- would normally bring up Neovim's "ATTENTION" prompt (and an empty tab if
-- you pick Quit/Abort). Instead, when the Neovim that owned the swap file is
-- gone, the file opens normally, a separate clean Neovim reads the swap
-- file's text, and that text is put into the buffer as an ordinary edit
-- (so `u` undoes it) with a notification. The old swap file is deleted only
-- after it was read successfully. If the swap belongs to a Neovim that's
-- still running, Neovim's own handling stays.

local api = vim.api
local uv = vim.uv

local DELAY_MS = 3000
local MAX_BYTES = 1024 * 1024
local group = api.nvim_create_augroup("UserAutosave", { clear = true })

-- Buffers we've told "too big for auto-save".
local big_noted = {}

local function too_big(buf)
  return api.nvim_buf_get_offset(buf, api.nvim_buf_line_count(buf)) > MAX_BYTES
end

-- mtime of each buffer's file as of our last read/write, to notice when
-- another program changed it.
local known_mtime = {}
local warned = {}

local function mtime(name)
  local st = uv.fs_stat(name)
  return st and (st.mtime.sec .. "." .. st.mtime.nsec) or nil
end

local function remember(buf)
  local name = api.nvim_buf_get_name(buf)
  if name ~= "" then
    known_mtime[buf] = mtime(name)
    warned[buf] = nil
  end
end

local function savable(buf)
  if not (api.nvim_buf_is_valid(buf) and api.nvim_buf_is_loaded(buf)) then
    return false
  end
  local bo = vim.bo[buf]
  if not bo.modified or bo.buftype ~= "" or bo.readonly or not bo.modifiable then
    return false
  end
  local name = api.nvim_buf_get_name(buf)
  return name ~= "" and vim.fn.isdirectory(vim.fs.dirname(name)) == 1 and not too_big(buf)
end

local function save(buf)
  if not savable(buf) then
    return
  end
  local name = api.nvim_buf_get_name(buf)
  local now = mtime(name)
  if now and known_mtime[buf] and now ~= known_mtime[buf] then
    if not warned[buf] then
      warned[buf] = true
      vim.notify(
        vim.fn.fnamemodify(name, ":~") .. " was changed by another program -- not auto-saving.\n"
          .. ":e! loads that version (drops your edits), :w! keeps yours.",
        vim.log.levels.WARN,
        { title = "Auto-save" }
      )
    end
    return
  end
  api.nvim_buf_call(buf, function()
    vim.cmd "silent! lockmarks update"
  end)
end

local function save_all()
  for _, buf in ipairs(api.nvim_list_bufs()) do
    save(buf)
  end
end

local timers = {}

local function schedule_save(buf)
  local t = timers[buf]
  if not t then
    t = uv.new_timer()
    timers[buf] = t
  end
  t:stop()
  t:start(DELAY_MS, 0, vim.schedule_wrap(function()
    save(buf)
  end))
end

api.nvim_create_autocmd({ "BufReadPost", "BufWritePost", "FileChangedShellPost" }, {
  group = group,
  callback = function(args)
    remember(args.buf)
  end,
})

api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
  group = group,
  callback = function(args)
    local buf = args.buf
    if savable(buf) then
      schedule_save(buf)
    elseif not big_noted[buf] and vim.bo[buf].modified and vim.bo[buf].buftype == ""
      and api.nvim_buf_get_name(buf) ~= "" and too_big(buf) then
      big_noted[buf] = true
      vim.notify(
        vim.fn.fnamemodify(api.nvim_buf_get_name(buf), ":~:.") .. " is over 1 MB: not auto-saved, use :w.",
        vim.log.levels.INFO,
        { title = "Auto-save" }
      )
    end
  end,
})

api.nvim_create_autocmd("BufLeave", {
  group = group,
  callback = function(args)
    save(args.buf)
  end,
})

api.nvim_create_autocmd({ "FocusLost", "QuitPre", "VimLeavePre" }, {
  group = group,
  callback = save_all,
})

api.nvim_create_autocmd("BufWipeout", {
  group = group,
  callback = function(args)
    local t = timers[args.buf]
    if t then
      t:stop()
      t:close()
      timers[args.buf] = nil
    end
    known_mtime[args.buf], warned[args.buf], big_noted[args.buf] = nil, nil, nil
  end,
})

-- Is the Neovim that wrote this swap file still running?
local function owner_alive(pid)
  if not pid or pid == 0 or uv.kill(pid, 0) ~= 0 then
    return false
  end
  -- After a reboot the pid may belong to some other program.
  local f = io.open("/proc/" .. pid .. "/comm")
  local comm = f and f:read "*l" or ""
  if f then
    f:close()
  end
  return comm:find("nvim", 1, true) ~= nil
end

-- The text a swap file holds, read by a clean Neovim (no config, no swap of
-- its own), or nil if that failed.
local function read_swap(swap)
  local tmp = vim.fn.tempname()
  vim.system({
    vim.v.progpath, "--clean", "--headless", "-n",
    "-c", "silent! recover! " .. vim.fn.fnameescape(swap),
    "-c", "silent! write! " .. vim.fn.fnameescape(tmp),
    "-c", "qa!",
  }):wait(10000)
  if vim.fn.filereadable(tmp) == 0 then
    return nil
  end
  local lines = vim.fn.readfile(tmp)
  os.remove(tmp)
  return lines
end

api.nvim_create_autocmd("SwapExists", {
  group = group,
  callback = function(args)
    local swap = vim.v.swapname
    local info = vim.fn.swapinfo(swap)
    if info.error or owner_alive(info.pid) then
      return -- Neovim's default handling
    end
    -- Open the file as saved (our buffer gets a swap file of its own); the
    -- old swap file's text is applied once the file is loaded.
    vim.v.swapchoice = "e"
    local buf = args.buf
    api.nvim_create_autocmd("BufReadPost", {
      group = group,
      buffer = buf,
      once = true,
      callback = function()
        vim.schedule(function()
          local name = vim.fn.fnamemodify(api.nvim_buf_get_name(buf), ":~")
          local lines = read_swap(swap)
          if not lines then
            vim.notify("Couldn't read the old swap file of " .. name .. "; it's kept:\n" .. swap,
              vim.log.levels.ERROR, { title = "Swap recovery" })
            return
          end
          os.remove(swap)
          if not api.nvim_buf_is_valid(buf)
            or vim.deep_equal(lines, api.nvim_buf_get_lines(buf, 0, -1, false)) then
            return -- the "unsaved edits" changed nothing
          end
          api.nvim_buf_set_lines(buf, 0, -1, false, lines)
          vim.notify(
            "Recovered unsaved edits from before a crash/reboot: " .. name
              .. "\nThey'll be auto-saved; u in that file undoes them.",
            vim.log.levels.WARN,
            { title = "Swap recovery" }
          )
        end)
      end,
    })
  end,
})
