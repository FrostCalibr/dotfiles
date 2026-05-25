-- ============================================================
-- PLUGINS.LUA — Extra plugins for normal editor feel
-- Place at: ~/.config/nvim/lua/plugins/extras.lua
-- LazyVim will auto-load this
-- ============================================================

return {

  -- ============================================================
  -- TELESCOPE — fuzzy finder (Ctrl+P, Ctrl+Shift+F)
  -- ============================================================
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      -- faster sorter (optional but recommended)
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    },
    config = function()
      require("telescope").setup({
        defaults = {
          -- show hidden files too
          file_ignore_patterns = { "node_modules", ".git/", ".cache" },
          vimgrep_arguments = {
            "rg", "--color=never", "--no-heading",
            "--with-filename", "--line-number",
            "--column", "--smart-case", "--hidden",
          },
        },
        pickers = {
          find_files = { hidden = true },
        },
      })
      pcall(require("telescope").load_extension, "fzf")
    end,
  },

  -- ============================================================
  -- NEO-TREE — file sidebar (Ctrl+B)
  -- ============================================================
  {
    "nvim-neo-tree/neo-tree.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
    opts = {
      window = { width = 30 },
      filesystem = {
        filtered_items = {
          visible = true,       -- show hidden files dimmed
          hide_dotfiles = false,
          hide_gitignored = false,
        },
        follow_current_file = { enabled = true },  -- auto-reveal open file
      },
    },
  },

  -- ============================================================
  -- TOGGLETERM — proper terminal (Ctrl+`)
  -- ============================================================
  {
    "akinsho/toggleterm.nvim",
    opts = {
      open_mapping  = [[<C-`>]],
      direction     = "horizontal",
      size          = 15,
      shade_terminals = true,
      start_in_insert = true,
    },
  },

  -- ============================================================
  -- MULTI-CURSOR — Ctrl+D to add cursors like VSCode/Sublime
  -- ============================================================
  {
    "mg979/vim-visual-multi",
    event = "BufReadPost",
    init = function()
      vim.g.VM_maps = {
        ["Find Under"]         = "<C-d>",   -- Ctrl+D add cursor at next match
        ["Find Subword Under"] = "<C-d>",
        ["Add Cursor Up"]      = "<C-A-Up>",
        ["Add Cursor Down"]    = "<C-A-Down>",
        ["Select All"]         = "<C-S-l>",
      }
    end,
  },

  -- ============================================================
  -- AUTO-PAIRS — auto close brackets, quotes etc
  -- ============================================================
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    opts = {
      check_ts = true,   -- use treesitter for smarter pairing
    },
  },

  -- ============================================================
  -- SURROUND — easily add/change quotes, brackets around text
  -- ============================================================
  {
    "kylechui/nvim-surround",
    event = "VeryLazy",
    opts = {},
  },

  -- ============================================================
  -- BETTER ESCAPE — jk or jj to exit insert (optional)
  -- ============================================================
  -- Uncomment if you want this:
  -- {
  --   "max397574/better-escape.nvim",
  --   opts = { mapping = { "jk", "jj" } },
  -- },

  -- ============================================================
  -- INDENT GUIDES — visual indentation lines
  -- ============================================================
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    opts = {
      indent = { char = "│" },
      scope  = { enabled = true },
    },
  },

  -- ============================================================
  -- GIT SIGNS — show git changes in gutter
  -- ============================================================
  {
    "lewis6991/gitsigns.nvim",
    opts = {
      signs = {
        add          = { text = "▎" },
        change       = { text = "▎" },
        delete       = { text = "" },
        topdelete    = { text = "" },
        changedelete = { text = "▎" },
      },
      -- Useful keymaps
      on_attach = function(buf)
        local gs = package.loaded.gitsigns
        local function bmap(mode, key, fn, desc)
          vim.keymap.set(mode, key, fn, { buffer = buf, desc = desc })
        end
        bmap("n", "<A-j>", gs.next_hunk,        "Next git change")
        bmap("n", "<A-k>", gs.prev_hunk,        "Prev git change")
        bmap("n", "<A-p>", gs.preview_hunk,     "Preview git change")
        bmap("n", "<A-r>", gs.reset_hunk,       "Revert git change")
        bmap("n", "<A-b>", gs.blame_line,       "Git blame line")
      end,
    },
  },

  -- ============================================================
  -- COLORIZER — show hex colors inline (#ff0000 etc)
  -- Useful for CSS/HTML
  -- ============================================================
  {
    "NvChad/nvim-colorizer.lua",
    event = "BufReadPost",
    opts = {
      user_default_options = {
        css    = true,
        html   = true,
        RRGGBB = true,
        names  = false,
      },
    },
  },

  -- ============================================================
  -- WHICH-KEY — shows keybind hints (like a cheatsheet popup)
  -- ============================================================
  {
    "folke/which-key.nvim",
    opts = {
      delay = 500,   -- show after 0.5s of holding a key
    },
  },

}
