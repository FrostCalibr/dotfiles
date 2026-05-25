-- ============================================================
-- KEYMAPS.LUA — Normal editor feel for Neovim / LazyVim
-- Place at: ~/.config/nvim/lua/config/keymaps.lua
-- ============================================================

local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- ============================================================
-- ALWAYS START IN INSERT MODE
-- ============================================================
vim.api.nvim_create_autocmd({ "VimEnter", "BufWinEnter" }, {
  callback = function()
    -- Don't force insert in special buffers (file tree, terminal, etc.)
    local ft = vim.bo.filetype
    local excluded = { "neo-tree", "NvimTree", "toggleterm", "TelescopePrompt", "lazy", "mason", "help" }
    for _, v in ipairs(excluded) do
      if ft == v then return end
    end
    if vim.fn.mode() == "n" then
      vim.cmd("startinsert")
    end
  end,
})

-- ============================================================
-- ESCAPE — get back to normal mode cleanly
-- ============================================================
map("i", "<Esc>", "<Esc>", opts)               -- Esc still works
map("i", "<C-c>", "<Esc>", opts)               -- Ctrl+C also exits insert

-- ============================================================
-- FILE OPERATIONS
-- ============================================================
map({ "i", "n" }, "<C-s>", "<Cmd>w<CR>",        vim.tbl_extend("force", opts, { desc = "Save" }))
map({ "i", "n" }, "<C-S-s>", "<Cmd>wa<CR>",     vim.tbl_extend("force", opts, { desc = "Save all" }))
map({ "i", "n" }, "<C-q>", "<Cmd>q<CR>",        vim.tbl_extend("force", opts, { desc = "Quit" }))
map({ "i", "n" }, "<C-S-q>", "<Cmd>qa!<CR>",    vim.tbl_extend("force", opts, { desc = "Force quit all" }))
-- New file
map({ "i", "n" }, "<C-n>", "<Cmd>enew<CR>",     vim.tbl_extend("force", opts, { desc = "New file" }))
-- Close current buffer (like closing a tab)
map({ "i", "n" }, "<C-w>", "<Cmd>bd<CR>",       vim.tbl_extend("force", opts, { desc = "Close buffer" }))

-- ============================================================
-- UNDO / REDO
-- ============================================================
map({ "i", "n" }, "<C-z>", "<Cmd>undo<CR>",     vim.tbl_extend("force", opts, { desc = "Undo" }))
map({ "i", "n" }, "<C-y>", "<Cmd>redo<CR>",     vim.tbl_extend("force", opts, { desc = "Redo" }))

-- ============================================================
-- CLIPBOARD — Copy / Paste / Cut
-- ============================================================
-- Copy (visual mode)
map("v", "<C-c>", '"+y',                        vim.tbl_extend("force", opts, { desc = "Copy" }))
-- Cut (visual mode)
map("v", "<C-x>", '"+d',                        vim.tbl_extend("force", opts, { desc = "Cut" }))
-- Paste (terminal sends Ctrl+Shift+V)
map({ "i", "n" }, "<C-S-v>", '"+p',             vim.tbl_extend("force", opts, { desc = "Paste" }))
map("v", "<C-S-v>", '"+p',                      vim.tbl_extend("force", opts, { desc = "Paste over selection" }))
-- Select all
map({ "i", "n" }, "<C-a>", "<Esc>ggVG",         vim.tbl_extend("force", opts, { desc = "Select all" }))

-- ============================================================
-- CURSOR MOVEMENT — Arrow keys + word jumping
-- ============================================================
-- Arrow keys work in normal mode
map("n", "<Up>",    "k", opts)
map("n", "<Down>",  "j", opts)
map("n", "<Left>",  "h", opts)
map("n", "<Right>", "l", opts)

-- Ctrl+Arrow = jump words (like every normal editor)
map({ "i", "n" }, "<C-Right>", "<C-Right>", opts)   -- next word
map({ "i", "n" }, "<C-Left>",  "<C-Left>",  opts)   -- prev word
map("n",          "<C-Right>", "w",         opts)
map("n",          "<C-Left>",  "b",         opts)

-- Home / End
map({ "i", "n" }, "<Home>", "<Home>", opts)
map({ "i", "n" }, "<End>",  "<End>",  opts)

-- Page Up / Down
map({ "i", "n" }, "<PageUp>",   "<PageUp>",   opts)
map({ "i", "n" }, "<PageDown>", "<PageDown>", opts)

-- ============================================================
-- SHIFT+ARROW SELECTION (like normal editors)
-- ============================================================
vim.opt.keymodel    = "startsel,stopsel"
vim.opt.selectmode  = "key,mouse"
vim.opt.selection   = "inclusive"

map({ "i", "n" }, "<S-Right>",   "<S-Right>",   opts)
map({ "i", "n" }, "<S-Left>",    "<S-Left>",    opts)
map({ "i", "n" }, "<S-Up>",      "<S-Up>",      opts)
map({ "i", "n" }, "<S-Down>",    "<S-Down>",    opts)
-- Shift+Ctrl+Arrow = select word by word
map({ "i", "n" }, "<C-S-Right>", "<C-S-Right>", opts)
map({ "i", "n" }, "<C-S-Left>",  "<C-S-Left>",  opts)
-- Shift+Home/End = select to start/end of line
map({ "i", "n" }, "<S-Home>",    "<S-Home>",    opts)
map({ "i", "n" }, "<S-End>",     "<S-End>",     opts)

-- ============================================================
-- EDITING SHORTCUTS
-- ============================================================
-- Ctrl+Backspace = delete previous word
map("i", "<C-BS>", "<C-w>", opts)
-- Ctrl+Delete = delete next word
map("i", "<C-Del>", "<C-o>dw", opts)
-- Duplicate line (Ctrl+D like Sublime/VSCode)
map({ "i", "n" }, "<C-d>", "<Cmd>t.<CR>", vim.tbl_extend("force", opts, { desc = "Duplicate line" }))
-- Move line up/down (Alt+Up/Down like VSCode)
map("n", "<A-Up>",   "<Cmd>m .-2<CR>==",        vim.tbl_extend("force", opts, { desc = "Move line up" }))
map("n", "<A-Down>", "<Cmd>m .+1<CR>==",         vim.tbl_extend("force", opts, { desc = "Move line down" }))
map("i", "<A-Up>",   "<Esc><Cmd>m .-2<CR>==gi",  vim.tbl_extend("force", opts, { desc = "Move line up" }))
map("i", "<A-Down>", "<Esc><Cmd>m .+1<CR>==gi",  vim.tbl_extend("force", opts, { desc = "Move line down" }))
map("v", "<A-Up>",   ":m '<-2<CR>gv=gv",         vim.tbl_extend("force", opts, { desc = "Move selection up" }))
map("v", "<A-Down>", ":m '>+1<CR>gv=gv",         vim.tbl_extend("force", opts, { desc = "Move selection down" }))
-- Tab / Shift+Tab indent in all modes
map("i", "<Tab>",   "<Tab>",   opts)
map("i", "<S-Tab>", "<C-d>",   opts)
map("v", "<Tab>",   ">gv",     opts)
map("v", "<S-Tab>", "<gv",     opts)
-- Toggle comment (Ctrl+/)
map({ "i", "n", "v" }, "<C-/>", "gcc", { remap = true, desc = "Toggle comment" })
-- Delete line (Ctrl+Shift+K like VSCode)
map({ "i", "n" }, "<C-S-k>", "<Cmd>d<CR>", vim.tbl_extend("force", opts, { desc = "Delete line" }))

-- ============================================================
-- SEARCH & REPLACE
-- ============================================================
-- Ctrl+F = find in current file
map({ "i", "n" }, "<C-f>", "<Cmd>/<CR>", vim.tbl_extend("force", opts, { desc = "Find in file" }))
-- Ctrl+H = find and replace
map({ "i", "n" }, "<C-h>", ":%s//gc<Left><Left><Left>", vim.tbl_extend("force", opts, { desc = "Find & replace" }))
-- F3 / Shift+F3 = next / prev search result
map({ "i", "n" }, "<F3>",   "n",  opts)
map({ "i", "n" }, "<S-F3>", "N",  opts)
-- Clear search highlight on Escape
map("n", "<Esc>", "<Cmd>noh<CR><Esc>", opts)

-- ============================================================
-- FILE FINDER & SEARCH (Telescope if available, fallback if not)
-- ============================================================
local ok, _ = pcall(require, "telescope")
if ok then
  local tb = require("telescope.builtin")
  -- Ctrl+P = find file
  map({ "i", "n" }, "<C-p>",   tb.find_files,                vim.tbl_extend("force", opts, { desc = "Find file" }))
  -- Ctrl+Shift+F = search text across project
  map({ "i", "n" }, "<C-S-f>", tb.live_grep,                 vim.tbl_extend("force", opts, { desc = "Search in project" }))
  -- Ctrl+Shift+O = go to symbol in file
  map({ "i", "n" }, "<C-S-o>", tb.lsp_document_symbols,      vim.tbl_extend("force", opts, { desc = "Go to symbol" }))
  -- Ctrl+Tab = open buffers list (like tabs)
  map({ "i", "n" }, "<C-Tab>", tb.buffers,                   vim.tbl_extend("force", opts, { desc = "Switch buffer" }))
  -- F1 = help / command search
  map({ "i", "n" }, "<F1>",    tb.help_tags,                 vim.tbl_extend("force", opts, { desc = "Help" }))
else
  -- Fallback without Telescope
  map({ "i", "n" }, "<C-p>",   "<Cmd>e **/*",                vim.tbl_extend("force", opts, { desc = "Find file (basic)" }))
  map({ "i", "n" }, "<C-Tab>", "<Cmd>bnext<CR>",             vim.tbl_extend("force", opts, { desc = "Next buffer" }))
end

-- ============================================================
-- LSP (hover, definition, rename, format, errors)
-- ============================================================
map({ "i", "n" }, "<F2>",     vim.lsp.buf.rename,            vim.tbl_extend("force", opts, { desc = "Rename symbol" }))
map({ "i", "n" }, "<F4>",     vim.lsp.buf.code_action,       vim.tbl_extend("force", opts, { desc = "Code action" }))
map({ "i", "n" }, "<F12>",    vim.lsp.buf.definition,        vim.tbl_extend("force", opts, { desc = "Go to definition" }))
map({ "i", "n" }, "<S-F12>",  vim.lsp.buf.references,        vim.tbl_extend("force", opts, { desc = "Find references" }))
map({ "i", "n" }, "<A-k>",    vim.lsp.buf.hover,             vim.tbl_extend("force", opts, { desc = "Hover docs" }))
map({ "i", "n" }, "<A-f>",    vim.lsp.buf.format,            vim.tbl_extend("force", opts, { desc = "Format file" }))
-- F8 = next error/warning
map({ "i", "n" }, "<F8>",     vim.diagnostic.goto_next,      vim.tbl_extend("force", opts, { desc = "Next error" }))
map({ "i", "n" }, "<S-F8>",   vim.diagnostic.goto_prev,      vim.tbl_extend("force", opts, { desc = "Prev error" }))
-- Ctrl+. = code action (like VSCode)
map({ "i", "n" }, "<C-.>",    vim.lsp.buf.code_action,       vim.tbl_extend("force", opts, { desc = "Code action" }))

-- ============================================================
-- TABS / BUFFERS (feel like browser/editor tabs)
-- ============================================================
map({ "i", "n" }, "<C-S-t>",  "<Cmd>tabnew<CR>",             vim.tbl_extend("force", opts, { desc = "New tab" }))
map({ "i", "n" }, "<A-Right>","<Cmd>bnext<CR>",              vim.tbl_extend("force", opts, { desc = "Next tab" }))
map({ "i", "n" }, "<A-Left>", "<Cmd>bprev<CR>",              vim.tbl_extend("force", opts, { desc = "Prev tab" }))

-- ============================================================
-- SPLITS
-- ============================================================
map({ "i", "n" }, "<C-S-Right>", "<Cmd>vsp<CR>",             vim.tbl_extend("force", opts, { desc = "Split right" }))
map({ "i", "n" }, "<C-S-Down>",  "<Cmd>sp<CR>",              vim.tbl_extend("force", opts, { desc = "Split down" }))
-- Move between splits with Alt+Arrow (without leaving insert mode)
map({ "i", "n" }, "<C-A-Right>", "<Cmd>wincmd l<CR>",        vim.tbl_extend("force", opts, { desc = "Focus right split" }))
map({ "i", "n" }, "<C-A-Left>",  "<Cmd>wincmd h<CR>",        vim.tbl_extend("force", opts, { desc = "Focus left split" }))
map({ "i", "n" }, "<C-A-Up>",    "<Cmd>wincmd k<CR>",        vim.tbl_extend("force", opts, { desc = "Focus upper split" }))
map({ "i", "n" }, "<C-A-Down>",  "<Cmd>wincmd j<CR>",        vim.tbl_extend("force", opts, { desc = "Focus lower split" }))

-- ============================================================
-- FILE TREE (Neo-tree or NvimTree)
-- ============================================================
map({ "i", "n" }, "<C-b>", "<Cmd>Neotree toggle<CR>",        vim.tbl_extend("force", opts, { desc = "Toggle file tree" }))

-- ============================================================
-- TERMINAL
-- ============================================================
map({ "i", "n" }, "<C-`>", "<Cmd>ToggleTerm<CR>",            vim.tbl_extend("force", opts, { desc = "Toggle terminal" }))
-- Escape terminal mode with Esc
map("t", "<Esc>", "<C-\\><C-n>", opts)

-- ============================================================
-- MULTI-CURSOR (if vim-visual-multi is installed)
-- ============================================================
-- Ctrl+Click or Ctrl+D to add cursor (handled by plugin itself)
-- Just making sure it doesn't conflict
