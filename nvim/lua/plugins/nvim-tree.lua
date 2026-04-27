return {
  "nvim-tree/nvim-tree.lua",
  opts = {
    view = {
      width = 30,
    },
    on_attach = function(bufnr)
      local api = require "nvim-tree.api"

      -- apply all default keymaps first
      api.config.mappings.default_on_attach(bufnr)

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
  },
}
