local utils = require("diffview.utils")
local config = require("diffview.config")
local renderer = require("diffview.renderer")
local Form = require("diffview.ui.panel").Form
local RevType = require("diffview.git.rev").RevType

---@param comp RenderComponent
---@param files FileEntry[]
local function render_files(comp, files)
  local line_idx = 0

  for i, file in ipairs(files) do
    local s
    if i == #files then
      s = "└   "
    else
      s = "│   "
    end
    comp:add_hl("DiffviewNonText", line_idx, 0, #s)

    local offset = #s
    comp:add_hl(renderer.get_git_hl(file.status), line_idx, offset, offset + 1)
    s = s .. file.status .. " "
    offset = #s
    local icon = renderer.get_file_icon(file.basename, file.extension, comp, line_idx, offset)
    offset = offset + #icon
    comp:add_hl("DiffviewFilePanelPath", line_idx, offset, offset + #file.parent_path + 1)
    comp:add_hl(
      "DiffviewFilePanelFileName",
      line_idx,
      offset + #file.parent_path + 1,
      offset + #file.basename
    )
    s = s .. icon .. file.path

    if file.stats then
      offset = #s + 1
      comp:add_hl(
        "DiffviewFilePanelInsertions",
        line_idx,
        offset,
        offset + string.len(file.stats.additions)
      )
      offset = offset + string.len(file.stats.additions) + 2
      comp:add_hl(
        "DiffviewFilePanelDeletions",
        line_idx,
        offset,
        offset + string.len(file.stats.deletions)
      )
      s = s .. " " .. file.stats.additions .. ", " .. file.stats.deletions
    end

    comp:add_line(s)
    line_idx = line_idx + 1
  end
end

---@param parent any RenderComponent struct
---@param entries LogEntry[]
local function render_entries(parent, entries)
  local c = config.get_config()
  local max_num_files = -1
  for _, entry in ipairs(entries) do
    if #entry.files > max_num_files then
      max_num_files = #entry.files
    end
  end

  for i, entry in ipairs(entries) do
    if not entry.status then
      print(vim.inspect(entry, { depth = 2 }))
    end
    local entry_struct = parent[i]
    local line_idx = 0
    local offset = 0

    local comp = entry_struct.commit.comp
    local s = ""
    if not entry.single_file then
      comp:add_hl("CursorLineNr", line_idx, 0, 3)
      s = (entry.folded and c.signs.fold_closed or c.signs.fold_open) .. " "
    end

    offset = #s
    comp:add_hl(renderer.get_git_hl(entry.status), line_idx, offset, offset + 1)
    s = s .. entry.status

    if not entry.single_file then
      offset = #s
      local counter = " "
        .. utils.str_left_pad(tostring(#entry.files), #tostring(max_num_files))
        .. " files"
      comp:add_hl("DiffviewFilePanelCounter", line_idx, offset, offset + #counter)
      s = s .. counter
    end

    if entry.stats then
      local adds = tostring(entry.stats.additions)
      local dels = tostring(entry.stats.deletions)
      local l = 7
      local w = l - (#adds + #dels)
      if w < 1 then
        l = (#adds + #dels) - ((#adds + #dels) % 2) + 2
        w = l - (#adds + #dels)
      end

      comp:add_hl("DiffviewNonText", line_idx, #s + 1, #s + 2)
      s = s .. " | "
      offset = #s
      comp:add_hl("DiffviewFilePanelInsertions", line_idx, offset, offset + #adds)
      comp:add_hl(
        "DiffviewFilePanelDeletions",
        line_idx,
        offset + #adds + w,
        offset + #adds + w + #dels
      )
      s = s .. adds .. string.rep(" ", w) .. dels .. " |"
      comp:add_hl("DiffviewNonText", line_idx, #s - 1, #s)
    end

    offset = #s + 1
    local subject = #entry.files > 0
        and entry.files[1].right.type == RevType.LOCAL
        and "[Not Committed Yet]"
      or utils.str_shorten(entry.commit.subject, 72)
    comp:add_hl("DiffviewFilePanelFileName", line_idx, offset, offset + #subject)
    s = s .. " " .. subject

    offset = #s + 1
    if entry.commit then
      -- 3 months
      local date = (
          os.difftime(os.time(), entry.commit.time) > 60 * 60 * 24 * 30 * 3
            and entry.commit.iso_date
          or entry.commit.rel_date
        )
      local info = entry.commit.author .. ", " .. date
      comp:add_hl("DiffviewFilePanelPath", line_idx, offset, offset + #info)
      s = s .. " " .. info
    end

    comp:add_line(s)
    line_idx = line_idx + 1

    if not entry.single_file and not entry.folded then
      render_files(entry_struct.files.comp, entry.files)
    end
  end
end

return {
  ---@param panel FileHistoryPanel
  file_history_panel = function(panel)
    if not panel.render_data then
      return
    end

    panel.render_data:clear()

    ---@type RenderComponent
    local comp = panel.components.header.comp
    local line_idx = 0

    -- root path
    local s = (
        panel.form == Form.COLUMN
          and utils.path_shorten(vim.fn.fnamemodify(panel.git_root, ":~"), panel.width - 6)
        or vim.fn.fnamemodify(panel.git_root, ":~")
      )
    comp:add_hl("DiffviewFilePanelRootPath", line_idx, 0, #s)
    comp:add_line(s)
    line_idx = line_idx + 1

    local offset
    if panel.single_file then
      local file = panel.entries[1].files[1]

      -- file path
      local icon = renderer.get_file_icon(file.basename, file.extension, comp, line_idx, 0)
      offset = #icon
      comp:add_hl("DiffviewFilePanelPath", line_idx, offset, offset + #file.parent_path + 1)
      comp:add_hl(
        "DiffviewFilePanelFileName",
        line_idx,
        offset + #file.parent_path + 1,
        offset + #file.basename
      )
      s = icon .. file.path
      comp:add_line(s)
    else
      s = "Showing history for: "
      comp:add_hl("DiffviewFilePanelPath", line_idx, 0, #s)
      offset = #s
      local paths = table.concat(panel.path_args, " ")
      comp:add_hl("DiffviewFilePanelFileName", line_idx, offset, offset + #paths)
      comp:add_line(s .. paths)
    end

    if panel.option_mapping then
      line_idx = line_idx + 1
      s = "Options: "
      comp:add_hl("DiffviewFilePanelPath", line_idx, 0, #s)
      offset = #s
      comp:add_hl("DiffviewFilePanelCounter", line_idx, offset, offset + #panel.option_mapping)
      comp:add_line(s .. panel.option_mapping)
    end

    -- title
    comp = panel.components.log.title.comp
    comp:add_line("")
    line_idx = 1
    s = "File History"
    comp:add_hl("DiffviewFilePanelTitle", line_idx, 0, #s)
    local change_count = "(" .. #panel.entries .. ")"
    comp:add_hl("DiffviewFilePanelCounter", line_idx, #s + 1, #s + 1 + string.len(change_count))
    s = s .. " " .. change_count
    comp:add_line(s)

    if #panel.entries > 0 then
      render_entries(panel.components.log.entries, panel.entries)
    end
  end,

  ---@param panel FHOptionPanel
  fh_option_panel = function(panel)
    if not panel.render_data then
      return
    end

    panel.render_data:clear()

    ---@type RenderComponent
    local comp = panel.components.switches.title.comp
    local line_idx = 0
    local offset

    local s = "Switches"
    comp:add_hl("DiffviewFilePanelTitle", line_idx, 0, #s)
    comp:add_line(s)

    for _, item in ipairs(panel.components.switches.items) do
      ---@type RenderComponent
      comp = item.comp
      local option = comp.context[2]
      local enabled = panel.parent.log_options[comp.context[1]]

      s = " " .. option[1] .. " "
      comp:add_hl("DiffviewDim1", 0, 0, #s)

      offset = #s
      comp:add_hl("DiffviewFilePanelFileName", 0, offset, offset + #option[3])
      s = s .. option[3] .. " ("

      offset = #s
      comp:add_hl(
        enabled and "DiffviewFilePanelCounter" or "DiffviewDim1",
        0,
        offset,
        offset + #option[2]
      )
      s = s .. option[2]

      offset = #s
      comp:add_hl("DiffviewFilePanelFileName", 0, offset, offset + 1)
      s = s .. ")"
      comp:add_line(s)
    end

    comp = panel.components.options.title.comp
    comp:add_line("")
    s = "Options"
    comp:add_hl("DiffviewFilePanelTitle", 1, 0, #s)
    comp:add_line(s)

    for _, item in ipairs(panel.components.options.items) do
      ---@type RenderComponent
      comp = item.comp
      local option = comp.context[2]
      local value = panel.parent.log_options[comp.context[1]] or ""

      s = " " .. option[1] .. " "
      comp:add_hl("DiffviewDim1", 0, 0, #s)

      offset = #s
      comp:add_hl("DiffviewFilePanelFileName", 0, offset, offset + #option[3])
      s = s .. option[3] .. " ("

      offset = #s
      local flag = option[2] .. value
      comp:add_hl(
        value ~= "" and "DiffviewFilePanelCounter" or "DiffviewDim1",
        0,
        offset,
        offset + #flag
      )
      s = s .. flag

      offset = #s
      comp:add_hl("DiffviewFilePanelFileName", 0, offset, offset + 1)
      s = s .. ")"
      comp:add_line(s)
    end
  end,
}
