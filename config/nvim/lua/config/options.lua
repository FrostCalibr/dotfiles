-- ============================================================
-- OPTIONS.LUA — Normal editor feel for Neovim / LazyVim
-- Place at: ~/.config/nvim/lua/config/options.lua
-- ============================================================

local opt = vim.opt

-- ============================================================
-- CLIPBOARD
-- ============================================================
opt.clipboard     = "unnamedplus"   -- use system clipboard always

-- ============================================================
-- MOUSE
-- ============================================================
opt.mouse         = "a"             -- mouse works in all modes
opt.mousescroll   = "ver:3,hor:6"   -- smooth scroll speed

-- ============================================================
-- LINE NUMBERS
-- ============================================================
opt.number        = true
opt.relativenumber = false          -- absolute numbers feel more natural

-- ============================================================
-- INDENTATION
-- ============================================================
opt.tabstop       = 4
opt.shiftwidth    = 4
opt.softtabstop   = 4
opt.expandtab     = true            -- spaces not tabs
opt.autoindent    = true
opt.smartindent   = true

-- ============================================================
-- WRAPPING
-- ============================================================
opt.wrap          = true
opt.linebreak     = true            -- wrap at word boundaries not mid-word
opt.breakindent   = true            -- wrapped lines keep indentation

-- ============================================================
-- SEARCH
-- ============================================================
opt.ignorecase    = true            -- case insensitive search
opt.smartcase     = true            -- unless you type uppercase
opt.hlsearch      = true            -- highlight matches
opt.incsearch     = true            -- live search as you type

-- ============================================================
-- APPEARANCE
-- ============================================================
opt.termguicolors = true            -- true color support
opt.showmode      = false           -- don't show -- INSERT -- (redundant with statusline)
opt.signcolumn    = "yes"           -- always show gutter (no layout jumps)
opt.colorcolumn   = ""              -- no column ruler (too distracting)
opt.cursorline    = true            -- highlight current line
opt.scrolloff     = 8               -- keep 8 lines above/below cursor
opt.sidescrolloff = 8

-- ============================================================
-- SPLITS
-- ============================================================
opt.splitright    = true            -- new vertical split goes right
opt.splitbelow    = true            -- new horizontal split goes below

-- ============================================================
-- COMPLETION
-- ============================================================
opt.completeopt   = "menuone,noinsert,noselect,popup"
opt.pumheight     = 10              -- max 10 items in autocomplete popup

-- ============================================================
-- FILES
-- ============================================================
opt.autoread      = true            -- reload file if changed outside nvim
opt.backup        = false
opt.swapfile      = false
opt.undofile      = true            -- persistent undo across sessions
opt.undodir       = vim.fn.expand("~/.local/share/nvim/undo")

-- ============================================================
-- BEHAVIOUR
-- ============================================================
opt.timeoutlen    = 500             -- faster key sequence timeout
opt.updatetime    = 250             -- faster diagnostics/hover
opt.confirm       = true            -- ask to save instead of erroring
opt.backspace     = "indent,eol,start"  -- backspace works everywhere
opt.virtualedit   = "block"         -- allow cursor past end of line in visual block

-- ============================================================
-- SELECTION (for shift+arrow to work like normal editors)
-- ============================================================
opt.keymodel      = "startsel,stopsel"
opt.selectmode    = "key,mouse"
opt.selection     = "inclusive"

-- ============================================================
-- STATUSLINE / WINBAR
-- ============================================================
opt.laststatus    = 3               -- single global statusline
opt.ruler         = true

-- ============================================================
-- FOLDING (off by default, too confusing)
-- ============================================================
opt.foldenable    = false

-- ============================================================
-- WHITESPACE DISPLAY
-- ============================================================
opt.list          = true
opt.listchars     = {
  tab   = "→ ",
  trail = "·",
  nbsp  = "␣",
}

-- ============================================================
-- FORMAT OPTIONS (stop auto-commenting new lines)
-- ============================================================
vim.api.nvim_create_autocmd("BufEnter", {
  callback = function()
    vim.opt.formatoptions:remove({ "c", "r", "o" })
  end,
})
