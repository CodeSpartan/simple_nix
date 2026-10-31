-- Faster "buffers" module for NvChad's tabufline (wired in chadrc.lua).
--
-- Upstream styles every buffer up to the current one, and for each of them
-- scans all buffers (re-reading vim.t.bufs, which copies the list) to make
-- names unique: O(n^2) per redraw. With ~600 buffers (the Notepad++ import
-- in ~/Documents/npp-tabs) a redraw took 1.5 s. This draws the same tabs but
-- styles only the visible ones and finds duplicate names in one pass.

local api = vim.api
local fn = vim.fn
local utils = require "nvchad.tabufline.utils"
local txt, btn = utils.txt, utils.btn

local function opts()
  return require("nvconfig").ui.tabufline
end

local function filename(str)
  return str:match "([^/\\]+)[/\\]*$"
end

local function new_hl(group1, group2)
  local fg = api.nvim_get_hl(0, { name = group1 }).fg
  local bg = api.nvim_get_hl(0, { name = "Tb" .. group2 }).bg
  api.nvim_set_hl(0, group1 .. group2, { fg = fg, bg = bg })
  return "%#" .. group1 .. group2 .. "#"
end

-- Width taken by the tabline's other modules (same strings upstream builds).
local function other_width()
  local o = opts()
  local w = 0
  for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
    if vim.bo[api.nvim_win_get_buf(win)].ft == o.treeOffsetFt then
      w = api.nvim_win_get_width(win) + 1
      break
    end
  end
  local str = btn(vim.g.toggle_theme_icon or "   ", "ThemeToggleBtn", "Toggle_theme")
    .. btn(" 󰅖 ", "CloseAllBufsBtn", "CloseAllBufs")
  local tabs = fn.tabpagenr "$"
  if tabs > 1 then
    if vim.g.TbTabsToggled == 1 then
      str = str .. " 󰅁 "
    else
      str = str .. " 󰐕  TABS "
      for nr = 1, tabs do
        str = str .. " " .. nr .. " "
      end
    end
  end
  return w + api.nvim_eval_statusline(str, { use_tabline = true }).width
end

-- Same look as upstream utils.style_buf; `dup` marks names used twice.
local function style_buf(nr, i, w, dup, cur, cur_mod)
  local o = opts()
  local icon = "󰈚 "
  local is_curbuf = cur == nr
  local tbHlName = "BufO" .. (is_curbuf and "n" or "ff")
  local icon_hl = new_hl("DevIconDefault", tbHlName)

  local path = api.nvim_buf_get_name(nr)
  local name = filename(path)
  if name and dup[name] then
    name = fn.fnamemodify(path, ":h:t") .. "/" .. name
  end
  name = name or " No Name "

  if name ~= " No Name " then
    local devicon, devicon_hl = require("nvim-web-devicons").get_icon(name)
    if devicon then
      icon = " " .. devicon .. " "
      icon_hl = new_hl(devicon_hl, tbHlName)
    end
  end

  local pad = math.floor((w - #name - 5) / 2)
  pad = pad <= 0 and 1 or pad

  local maxname_len = w - 5
  name = string.sub(name, 1, maxname_len - 2) .. (#name > maxname_len and ".." or "")
  name = txt(name, tbHlName)

  local num = o.numbers and txt(i .. " ", tbHlName) or ""
  name = string.rep(" ", pad - 1) .. (num .. icon_hl .. icon .. name) .. string.rep(" ", pad - 1)
  local close_btn = btn(" 󰅖 ", nil, "KillBuf", nr)
  name = btn(name, nil, "GoToBuf", nr)

  if is_curbuf then
    close_btn = cur_mod and txt("  ", "BufOnModified") or txt(close_btn, "BufOnClose")
  else
    local mod = api.nvim_get_option_value("mod", { buf = nr })
    close_btn = mod and txt("  ", "BufOffModified") or txt(close_btn, "BufOffClose")
  end

  return txt(name .. close_btn, tbHlName)
end

return function()
  local bufwidth = opts().bufwidth
  local bufs = vim.tbl_filter(api.nvim_buf_is_valid, vim.t.bufs or {})
  vim.t.bufs = bufs

  local seen, dup = {}, {}
  local cur, ci = api.nvim_get_current_buf(), nil
  for i, nr in ipairs(bufs) do
    local name = filename(api.nvim_buf_get_name(nr))
    if name then
      dup[name] = seen[name] or nil
      seen[name] = true
    end
    if nr == cur then
      ci = i
    end
  end

  -- Show buffers from the start; once the current one would fall off the
  -- right edge, scroll so one more buffer stays visible after it (unlike
  -- upstream, which makes the current one the last), so you can see there
  -- are more. If the current buffer isn't in the list (e.g. the file tree),
  -- show the last ones.
  local n = #bufs
  local fit = math.max(1, math.floor((vim.o.columns - other_width()) / bufwidth))
  local last = n
  if ci then
    local ahead = fit >= 2 and 1 or 0
    last = math.max(math.min(fit, n), math.min(ci + ahead, n))
  end
  local first = math.max(1, last - fit + 1)

  local cur_mod = api.nvim_get_option_value("mod", { buf = 0 })
  local out = {}
  for i = first, last do
    out[#out + 1] = style_buf(bufs[i], i, bufwidth, dup, cur, cur_mod)
  end
  return table.concat(out) .. txt("%=", "Fill")
end
