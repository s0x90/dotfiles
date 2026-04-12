-- This file needs to have same structure as nvconfig.lua
-- https://github.com/NvChad/ui/blob/v3.0/lua/nvconfig.lua
-- Please read that file to know all available options :(

---@type ChadrcConfig
local M = {}

M.base46 = {
  theme = "material-darker",

  hl_override = {
    NvimTreeNormal = { bg = "NONE" },
    NvimTreeNormalNC = { bg = "NONE" },
    NvimTreeWinSeparator = { fg = "light_grey", bg = "NONE" },
    NvimTreeCursorLine = { bg = "one_bg" },
    WinSeparator = { fg = "light_grey" },
    TbFill = { bg = "black" },           -- tabline empty space: #212121
    TbBufOff = { bg = "black" },         -- inactive buffer tabs
    TbBufOffClose = { bg = "black" },    -- close icon on inactive tabs
    TbBufOffModified = { bg = "black" }, -- modified icon on inactive tabs
  },
}

-- M.nvdash = { load_on_startup = true }

M.ui = {
  statusline = {
    modules = {
      file = function()
        local stbufnr = vim.api.nvim_win_get_buf(vim.g.statusline_winid or 0)

        if vim.bo[stbufnr].filetype == "NvimTree" then
          local ok, api = pcall(require, "nvim-tree.api")
          if ok then
            local node = api.tree.get_node_under_cursor()
            if node and node.name then
              local icon = "󰈚"
              local devicons_ok, devicons = pcall(require, "nvim-web-devicons")
              if devicons_ok and node.type == "file" then
                local ft_icon = devicons.get_icon(node.name)
                icon = ft_icon or icon
              elseif node.type == "directory" then
                icon = node.open and "" or ""
              end
              return "%#St_file# " .. icon .. " " .. node.name .. " %#St_file_sep#" .. ""
            end
          end
          return ""
        end

        local utils = require "nvchad.stl.utils"
        local x = utils.file()
        local name = " " .. x[2] .. " "
        return "%#St_file# " .. x[1] .. name .. "%#St_file_sep#" .. ""
      end,
    },
  },
}

return M
