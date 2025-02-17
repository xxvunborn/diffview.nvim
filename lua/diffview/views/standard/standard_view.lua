local oop = require("diffview.oop")
local FileEntry = require("diffview.views.file_entry").FileEntry
local View = require("diffview.views.view").View
local LayoutMode = require("diffview.views.view").LayoutMode
local Panel = require("diffview.ui.panel").Panel
local api = vim.api

local M = {}

---@class StandardView
---@field panel Panel
---@field left_winid integer
---@field right_winid integer
---@field nulled boolean
local StandardView = View
StandardView = oop.create_class("StandardView", View)

---StandardView constructor
---@return StandardView
function StandardView:init()
 StandardView:super().init(self)
  self.nulled = false
  self.panel = Panel()
end

---@Override
function StandardView:close()
  self.panel:destroy()

  if self.tabpage and api.nvim_tabpage_is_valid(self.tabpage) then
    local pagenr = api.nvim_tabpage_get_number(self.tabpage)
    vim.cmd("tabclose " .. pagenr)
  end
end

---@Override
function StandardView:init_layout()
  local split_cmd = self.layout_mode == LayoutMode.VERTICAL and "sp" or "vsp"
  self.left_winid = api.nvim_get_current_win()
  FileEntry.load_null_buffer(self.left_winid)
  vim.cmd("belowright " .. split_cmd)
  self.right_winid = api.nvim_get_current_win()
  FileEntry.load_null_buffer(self.right_winid)
  self.panel:open()
end

---@Override
---Checks the state of the view layout.
---@return LayoutState
function StandardView:validate_layout()
  ---@class LayoutState
  ---@field tabpage boolean
  ---@field left_win boolean
  ---@field right_win boolean
  ---@field valid boolean
  local state = {
    tabpage = api.nvim_tabpage_is_valid(self.tabpage),
    left_win = api.nvim_win_is_valid(self.left_winid),
    right_win = api.nvim_win_is_valid(self.right_winid),
  }
  state.valid = state.tabpage and state.left_win and state.right_win
  return state
end

---@Override
---Recover the layout after the user has messed it up.
---@param state LayoutState
function StandardView:recover_layout(state)
  self.ready = false

  if not state.tabpage then
    vim.cmd("tab split")
    self.tabpage = api.nvim_get_current_tabpage()
    self.panel:close()
    self:init_layout()
    self.ready = true
    return
  end

  api.nvim_set_current_tabpage(self.tabpage)
  self.panel:close()
  local split_cmd = self.layout_mode == LayoutMode.VERTICAL and "sp" or "vsp"

  if not state.left_win and not state.right_win then
    self:init_layout()
  elseif not state.left_win then
    api.nvim_set_current_win(self.right_winid)
    vim.cmd("aboveleft " .. split_cmd)
    self.left_winid = api.nvim_get_current_win()
    self.panel:open()
  elseif not state.right_win then
    api.nvim_set_current_win(self.left_winid)
    vim.cmd("belowright " .. split_cmd)
    self.right_winid = api.nvim_get_current_win()
    self.panel:open()
  end

  self.ready = true
end

---@Override
---Ensure both left and right windows exist in the view's tabpage.
function StandardView:ensure_layout()
  local state = self:validate_layout()
  if not state.valid then
    self:recover_layout(state)
  end
end

M.StandardView = StandardView

return M
