local utils = require("diffview.utils")
local git = require("diffview.git.utils")
local lib = require("diffview.lib")
local RevType = require("diffview.git.rev").RevType
local DiffView = require("diffview.views.diff.diff_view").DiffView
local api = vim.api

local function prepare_goto_file(view)
  local file = view:infer_cur_file()
  if file then
    if not file.right.type == RevType.LOCAL then
      -- Ensure file exists
      if vim.fn.filereadable(file.absolute_path) ~= 1 then
        utils.err(string.format(
          "File does not exist on disk: '%s'",
          vim.fn.fnamemodify(file.absolute_path, ":.")
        ))
        return
      end
    end
    return file
  end
end

---@param view FileHistoryView
return function(view)
  return {
    tab_enter = function()
      local file = view.panel.cur_item[2]
      if file then
        file:attach_buffers()
      end
    end,
    tab_leave = function()
      local file = view.panel.cur_item[2]
      if file then
        file:detach_buffers()
      end
    end,
    win_closed = function(winid)
      if winid and winid == view.panel.option_panel.winid then
        local op = view.panel.option_panel
        if not utils.tbl_deep_equals(op.option_state, view.panel.log_options) then
          op.option_state = nil
          view.panel.option_panel.winid = nil
          view.panel:update_entries()
          view:next_item()
        end
      end
    end,
    open_in_diffview = function()
      if view.panel:is_cur_win() then
        local item = view.panel:get_item_at_cursor()
        if item then
          ---@type FileEntry
          local file
          if item.files then
            file = item.files[1]
          else
            file = item
          end

          if file then
            ---@type DiffView
            local new_view = DiffView({
              git_root = view.git_root,
              rev_arg = git.rev_to_pretty_string(file.left, file.right),
              left = file.left,
              right = file.right,
              options = {},
            })

            lib.add_view(new_view)
            new_view:open()
          end
        end
      end
    end,
    select_next_entry = function()
      view:next_item()
    end,
    select_prev_entry = function()
      view:prev_item()
    end,
    next_entry = function()
      view.panel:highlight_next_file()
    end,
    prev_entry = function()
      view.panel:highlight_prev_item()
    end,
    select_entry = function()
      if view.panel:is_cur_win() then
        local item = view.panel:get_item_at_cursor()
        if item then
          -- print(vim.inspect(item))
          if item.files then
            if view.panel.single_file then
              view:set_file(item.files[1], true)
            else
              view.panel:toggle_entry_fold(item)
            end
          else
            view:set_file(item, true)
          end
        end
      end
    end,
    goto_file = function()
      local file = prepare_goto_file(view)
      if file then
        local target_tab = lib.get_prev_non_view_tabpage()
        if target_tab then
          api.nvim_set_current_tabpage(target_tab)
          vim.cmd("sp " .. vim.fn.fnameescape(file.absolute_path))
          vim.cmd("diffoff")
        else
          vim.cmd("tabe " .. vim.fn.fnameescape(file.absolute_path))
          vim.cmd("diffoff")
        end
      end
    end,
    goto_file_split = function()
      local file = prepare_goto_file(view)
      if file then
        vim.cmd("sp " .. vim.fn.fnameescape(file.absolute_path))
        vim.cmd("diffoff")
      end
    end,
    goto_file_tab = function()
      local file = prepare_goto_file(view)
      if file then
        vim.cmd("tabe " .. vim.fn.fnameescape(file.absolute_path))
        vim.cmd("diffoff")
      end
    end,
    focus_files = function()
      view.panel:focus(true)
    end,
    toggle_files = function()
      view.panel:toggle()
    end,
    open_all_folds = function()
      if view.panel:is_cur_win() and not view.panel.single_file then
        for _, entry in ipairs(view.panel.entries) do
          entry.folded = false
        end
        view.panel:render()
        view.panel:redraw()
      end
    end,
    close_all_folds = function()
      if view.panel:is_cur_win() and not view.panel.single_file then
        for _, entry in ipairs(view.panel.entries) do
          entry.folded = true
        end
        view.panel:render()
        view.panel:redraw()
      end
    end,
    close = function()
      if view.panel.option_panel:is_cur_win() then
        view.panel.option_panel:close()
      elseif view.panel:is_cur_win() then
        view.panel:close()
      elseif view:is_cur_tabpage() then
        view:close()
      end
    end,
    options = function()
      view.panel.option_panel:open()
    end,
    select = function()
      if view.panel.option_panel:is_cur_win() then
        local item = view.panel.option_panel:get_item_at_cursor()
        if item then
          view.panel.option_panel.emitter:emit("set_option", item[1])
        end
      end
    end,
  }
end
