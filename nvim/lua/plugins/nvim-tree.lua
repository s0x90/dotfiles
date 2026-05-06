return {
  "nvim-tree/nvim-tree.lua",
  cmd = { "NvimTreeToggle", "NvimTreeFocus", "NvimTreeFindFile", "NvimTreeDebugIcons" },
  init = function()
    -- Register the debug command at startup so it is available even when
    -- nvim-tree has not been loaded yet. Calling it manually asks Lazy to
    -- load the plugin via require("lazy").load(...), then reads the
    -- populated runtime config.
    vim.api.nvim_create_user_command("NvimTreeDebugIcons", function()
      pcall(function()
        require("lazy").load({ plugins = { "nvim-tree.lua" } })
      end)

      local ok_cfg, cfg = pcall(require, "nvim-tree.config")
      if not ok_cfg or type(cfg) ~= "table" or type(cfg.g) ~= "table" then
        vim.notify("nvim-tree config unavailable: " .. tostring(cfg), vim.log.levels.ERROR)
        return
      end
      print(vim.inspect({
        folder_glyphs   = cfg.g.renderer.icons.glyphs.folder,
        folder_devicons = cfg.g.renderer.icons.web_devicons.folder,
        show            = cfg.g.renderer.icons.show,
      }))
    end, { desc = "Print nvim-tree runtime icon config", force = true })
  end,
  opts = function()
    -- Pull NvChad's defaults if available. This also loads base46 highlights
    -- for nvim-tree (NvimTreeFolderIcon etc.) via its internal dofile.
    -- If it fails (fresh bootstrap, base46 cache missing, NvChad refactor),
    -- fall back to an empty table so nvim-tree still sets up.
    local ok, base_or_err = pcall(require, "nvchad.configs.nvimtree")
    local base = {}
    if ok and type(base_or_err) == "table" then
      base = base_or_err
    elseif ok then
      -- Module loaded but returned the wrong shape; don't feed it to
      -- vim.tbl_deep_extend or it will throw a generic type error later.
      vim.schedule(function()
        vim.notify(
          "nvim-tree: NvChad defaults returned " .. type(base_or_err) .. ", expected table; using local defaults",
          vim.log.levels.WARN
        )
      end)
    else
      vim.schedule(function()
        vim.notify(
          "nvim-tree: NvChad defaults failed. Run :Lazy sync, restart Neovim, "
            .. "or rebuild Base46 cache with :lua require('base46').load_all_highlights(). Details: "
            .. tostring(base_or_err),
          vim.log.levels.ERROR
        )
      end)
    end

    -- Preserve any base on_attach so a future NvChad-provided one is not
    -- silently swallowed by our override. Require a callable; truthy-but-
    -- not-function values would explode at tree-attach time.
    local base_on_attach = nil
    if type(base.on_attach) == "function" then
      base_on_attach = base.on_attach
    end

    -- Folder glyphs. Use vim.fn.nr2char so codepoints are explicit and
    -- immune to clipboard / encoding round-trips. Note: these are still
    -- Nerd Font private-use codepoints; render depends on the active font.
    local function glyph(cp)
      return vim.fn.nr2char(cp)
    end

    local folder_closed       = glyph(0xE5FF) -- modern filled, closed (nf-cod-folder)
    local folder_open         = glyph(0xE5FE) -- modern filled, open   (nf-cod-folder_opened)
    -- Empty folders intentionally use a visually distinct outline glyph;
    -- accept the mixed icon family to keep "empty vs non-empty" obvious.
    local folder_empty        = glyph(0xF114) -- thin/outline, closed
    local folder_empty_open   = glyph(0xF115) -- thin/outline, open
    local folder_symlink      = glyph(0xF482) -- nf-oct-file_symlink_directory
    local folder_symlink_open = folder_symlink -- same glyph open/closed; symlink-ness matters more than open state

    return vim.tbl_deep_extend("force", base, {
      renderer = {
        indent_markers = {
          enable = true,
          icons = {
            corner = "└",
            edge   = "│",
            item   = "│",
            bottom = "─",
            none   = " ",
          },
        },
        icons = {
          -- Force folder web-devicons OFF so our glyphs are authoritative.
          -- Otherwise nvim-tree calls nvim-web-devicons.get_icon(name) for
          -- folders and bypasses the glyphs.folder table entirely.
          web_devicons = {
            file = {
              enable = true,
              color  = true,
            },
            folder = {
              enable = false,
              color  = true,
            },
          },
          show = {
            file         = true,
            folder       = true,  -- explicitly show folder icon column
            folder_arrow = false, -- hide chevron column
            git          = true,
          },
          glyphs = {
            folder = {
              default      = folder_closed,
              open         = folder_open,
              empty        = folder_empty,
              empty_open   = folder_empty_open,
              symlink      = folder_symlink,
              symlink_open = folder_symlink_open,
            },
          },
        },
      },
      on_attach = function(bufnr)
        local api = require "nvim-tree.api"

        -- Run base on_attach if upstream provided one; otherwise apply the
        -- default keymaps. This keeps us forward-compatible with NvChad
        -- adding its own on_attach later.
        if base_on_attach then
          base_on_attach(bufnr)
        else
          api.config.mappings.default_on_attach(bufnr)
        end

        local function opts(desc)
          return { desc = "nvim-tree: " .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
        end

        local function open_if_node()
          local node = api.tree.get_node_under_cursor()
          if node then
            api.node.open.edit(node)
          end
        end

        -- override <CR> with nil-guard to prevent E5108 on empty lines
        vim.keymap.set("n", "<CR>", open_if_node, opts "Open")
        -- guard for 'o' which uses the same open function
        vim.keymap.set("n", "o", open_if_node, opts "Open")

        -- 'h' collapses the containing directory:
        -- - on an opened directory: collapse it
        -- - on a file or closed dir: jump to parent and collapse it
        local function collapse_parent()
          local node = api.tree.get_node_under_cursor()
          if not node then
            return
          end
          if node.type == "directory" and node.open then
            api.node.open.edit(node) -- toggles -> closes
            return
          end
          if node.parent then
            api.node.navigate.parent()
            local parent = api.tree.get_node_under_cursor()
            if parent and parent.type == "directory" and parent.open then
              api.node.open.edit(parent)
            end
          end
        end

        vim.keymap.set("n", "h", collapse_parent, opts "Collapse parent directory")
      end,
    })
  end,
}
