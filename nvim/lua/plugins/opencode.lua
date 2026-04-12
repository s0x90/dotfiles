return {
  "nickjvandyke/opencode.nvim",
  version = "*", -- Latest stable release
  lazy = false,
  dependencies = {
    {
      -- `snacks.nvim` integration is recommended, but optional
      ---@module "snacks" <- Loads `snacks.nvim` types for configuration intellisense
      "folke/snacks.nvim",
      optional = false,
      opts = {
        input = {}, -- Enhances `ask()`
        picker = { -- Enhances `select()`
          actions = {
            opencode_send = function(...)
              return require("opencode").snacks_picker_send(...)
            end,
          },
          win = {
            input = {
              keys = {
                ["<a-a>"] = { "opencode_send", mode = { "n", "i" } },
              },
            },
          },
        },
      },
    },
  },
  config = function()
    -- WezTerm pane management for opencode (fully async — never blocks the UI)
    local opencode_wez = { pane_id = nil }

    --- Check if a WezTerm pane exists, then call `cb(exists)` on the main loop.
    local function wezterm_pane_exists_async(pane_id, cb)
      if not pane_id then
        return cb(false)
      end
      vim.system({ "wezterm", "cli", "list", "--format", "json" }, { text = true }, function(out)
        vim.schedule(function()
          if out.code ~= 0 then
            return cb(false)
          end
          local ok, panes = pcall(vim.json.decode, out.stdout)
          if not ok or type(panes) ~= "table" then
            return cb(false)
          end
          for _, pane in ipairs(panes) do
            if tostring(pane.pane_id) == tostring(pane_id) then
              return cb(true)
            end
          end
          cb(false)
        end)
      end)
    end

    --- Open an opencode split pane (skips the redundant pane-exists check).
    local function wezterm_start()
      vim.system(
        { "wezterm", "cli", "split-pane", "--bottom", "--percent", "35", "--", "opencode", "--port" },
        { text = true },
        function(out)
          vim.schedule(function()
            if out.code ~= 0 then
              return
            end
            opencode_wez.pane_id = (out.stdout or ""):match("^%d+")
            if vim.env.WEZTERM_PANE then
              vim.system({ "wezterm", "cli", "activate-pane", "--pane-id", vim.env.WEZTERM_PANE })
            end
          end)
        end
      )
    end

    --- Kill the opencode pane (skips the redundant pane-exists check).
    local function wezterm_stop()
      local id = opencode_wez.pane_id
      opencode_wez.pane_id = nil
      if id then
        vim.system({ "wezterm", "cli", "kill-pane", "--pane-id", tostring(id) })
      end
    end

    --- Toggle: one async pane-exists check, then start or stop without re-checking.
    local function wezterm_toggle()
      wezterm_pane_exists_async(opencode_wez.pane_id, function(exists)
        if exists then
          wezterm_stop()
        else
          wezterm_start()
        end
      end)
    end

    ---@type opencode.Opts
    vim.g.opencode_opts = {
      server = {
        toggle = wezterm_toggle,
        start = wezterm_start,
        stop = wezterm_stop,
      },
    }

    vim.o.autoread = true -- Required for `opts.events.reload`

    -- Recommended/example keymaps
    vim.keymap.set({ "n", "x" }, "<C-a>", function()
      require("opencode").ask("@this: ", { submit = true })
    end, { desc = "Ask opencode…" })
    vim.keymap.set({ "n", "x" }, "<C-x>", function()
      require("opencode").select()
    end, { desc = "Execute opencode action…" })
    vim.keymap.set({ "n", "t" }, "<C-.>", function()
      require("opencode").toggle()
    end, { desc = "Toggle opencode" })

    vim.keymap.set({ "n", "x" }, "go", function()
      return require("opencode").operator "@this "
    end, { desc = "Add range to opencode", expr = true })
    vim.keymap.set("n", "goo", function()
      return require("opencode").operator "@this " .. "_"
    end, { desc = "Add line to opencode", expr = true })

    vim.keymap.set("n", "<S-C-u>", function()
      require("opencode").command "session.half.page.up"
    end, { desc = "Scroll opencode up" })
    vim.keymap.set("n", "<S-C-d>", function()
      require("opencode").command "session.half.page.down"
    end, { desc = "Scroll opencode down" })

    -- You may want these if you use the opinionated `<C-a>` and `<C-x>` keymaps above — otherwise consider `<leader>o…` (and remove terminal mode from the `toggle` keymap)
    vim.keymap.set("n", "+", "<C-a>", { desc = "Increment under cursor", noremap = true })
    vim.keymap.set("n", "-", "<C-x>", { desc = "Decrement under cursor", noremap = true })
  end,
}
