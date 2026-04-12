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
-- M.ui = {
--       tabufline = {
--          lazyload = false
--      }
-- }
return M
