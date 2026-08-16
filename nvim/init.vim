"
" ██╗███╗   ██╗██╗████████╗██╗   ██╗██╗███╗   ███╗
" ██║████╗  ██║██║╚══██╔══╝██║   ██║██║████╗ ████║
" ██║██╔██╗ ██║██║   ██║   ██║   ██║██║██╔████╔██║
" ██║██║╚██╗██║██║   ██║   ╚██╗ ██╔╝██║██║╚██╔╝██║
" ██║██║ ╚████║██║   ██║██╗ ╚████╔╝ ██║██║ ╚═╝ ██║
" ╚═╝╚═╝  ╚═══╝╚═╝   ╚═╝╚═╝  ╚═══╝  ╚═╝╚═╝     ╚═╝
"
"	@adinvadim
"
"
" Inspired by
" https://github.com/elijahmanor/dotfiles/blob/master/nvim/.config/nvim/init.vim
" https://github.com/nicknisi/dotfiles/blob/main/config/nvim/

if $VEIL_NVIM ==# '1'
  for s:veil_bin in ['/usr/local/bin', '/opt/homebrew/bin', expand('~/.n/bin')]
    if isdirectory(s:veil_bin) && stridx(':' . $PATH . ':', ':' . s:veil_bin . ':') < 0
      let $PATH = s:veil_bin . ':' . $PATH
    endif
  endfor

  let s:veil_node = exepath('node')
  if executable(s:veil_node)
    let g:coc_node_path = s:veil_node
  endif
  let g:loaded_claudecode = 1
endif

" Sets {{{
set exrc
set relativenumber
set nu
set nohlsearch
set mouse=a
set hidden
set splitright
set splitbelow
set noerrorbells
set nowrap
set formatoptions-=t
set ignorecase
set smartcase
set noswapfile
set nobackup
let s:undo_dir = stdpath('state') . '/undo'
if !isdirectory(s:undo_dir)
  call mkdir(s:undo_dir, 'p', 0700)
endif
if filewritable(s:undo_dir) == 2
  let &undodir = s:undo_dir
  set undofile
endif
set incsearch
set termguicolors
set scrolloff=2
set noshowmode
set completeopt=menu,menuone,noselect
set signcolumn=yes
set number
set updatetime=300
set encoding=UTF-8
set clipboard+=unnamedplus " Copy paste between vim and everything else
set nojoinspaces " don't autoinsert two spaces after '.', '?', '!' for join command
set showcmd " extra info at end of command line
set wildignore+=*/node_modules/**

set noemoji
filetype plugin indent on

" Always show the signcolumn, otherwise it would shift the text each time
" diagnostics appear/become resolved.
if has("nvim-0.5.0") || has("patch-8.1.1564")
  " Recently vim can merge signcolumn and number column into one
  set signcolumn=number
else
  set signcolumn=yes
endif

" folding
" set foldmethod=syntax "syntax highlighting items specify folds
" set foldcolumn=1 "defines 1 col at window left, to indicate folding
" let javaScript_fold=1 "activate folding by JS syntax
" set foldlevelstart=99 "start file with all folds opened

set foldlevel=20
set foldmethod=expr
set foldexpr=nvim_treesitter#foldexpr()

" for demo
" set expandtab
" set tabstop=2
" set softtabstop=2
" set shiftwidth=2
" set smartindent

" attempt to speed-up vim
set ttyfast
set lazyredraw
" }}}

" Plugins

call plug#begin('~/.local/share/nvim/plugged')

" Dashboard

" UI
Plug 'nvim-tree/nvim-web-devicons'
Plug 'nvim-lualine/lualine.nvim'
Plug 'akinsho/nvim-bufferline.lua'
Plug 'norcalli/nvim-colorizer.lua', { 'branch': 'color-editor' }
Plug 'karb94/neoscroll.nvim'
Plug 'folke/which-key.nvim'
Plug 'kyazdani42/nvim-tree.lua'
Plug 'nvim-lua/popup.nvim'
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-pack/nvim-spectre'
Plug 'nvim-telescope/telescope.nvim'
Plug 'LinArcX/telescope-env.nvim'
Plug 'nvim-telescope/telescope-fzf-native.nvim', { 'do': 'make' }
Plug 'nvim-telescope/telescope-file-browser.nvim'
Plug 'nvim-telescope/telescope-ui-select.nvim'
Plug 'sudormrfbin/cheatsheet.nvim'
Plug 'ThePrimeagen/harpoon'
Plug 'rcarriga/nvim-notify'
Plug 'kevinhwang91/promise-async'
Plug 'kevinhwang91/nvim-ufo'
Plug 'easymotion/vim-easymotion'


Plug 'windwp/nvim-autopairs'
Plug 'vim-test/vim-test'
Plug 'preservim/vimux'
Plug 'svermeulen/vimpeccable'
Plug 'jszakmeister/vim-togglecursor'
Plug 'editorconfig/editorconfig-vim'

" tpope plugins
Plug 'tpope/vim-surround'
Plug 'tpope/vim-commentary'
Plug 'tpope/vim-sleuth'
Plug 'tpope/vim-repeat'

" File Management


" Themes
Plug 'arcticicestudio/nord-vim'
Plug 'bluz71/vim-nightfly-guicolors'
"Plug 'dracula/vim', { 'as': 'dracula' }
Plug '4513ECHO/vim-colors-hatsunemiku'
Plug 'projekt0n/github-nvim-theme'
Plug 'shaunsingh/solarized.nvim'
Plug 'folke/tokyonight.nvim'


" Syntax
Plug 'nvim-treesitter/nvim-treesitter'
Plug 'nvim-treesitter/nvim-treesitter-context'
"Plug 'posva/vim-vue'
Plug 'JoosepAlviste/nvim-ts-context-commentstring'
Plug 'delphinus/vim-firestore'
Plug 'hashivim/vim-terraform'
Plug 'github/copilot.vim'
Plug 'folke/snacks.nvim'
Plug 'coder/claudecode.nvim'
Plug 'gaoDean/autolist.nvim'
Plug 'axelvc/template-string.nvim'

Plug 'OXY2DEV/markview.nvim'
Plug 'iamcco/markdown-preview.nvim', { 'do': 'cd app && npx --yes yarn install' }
" Plug 'roobert/tailwindcss-colorizer-cmp.nvim'


" Coc
Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'yaegassy/coc-tailwindcss3', {'do': 'yarn install --frozen-lockfile'}
Plug 'yaegassy/coc-volar', {'do': 'yarn install --frozen-lockfile'}
Plug 'yaegassy/coc-volar-tools', {'do': 'yarn install --frozen-lockfile'}
Plug 'neoclide/coc-tsserver', {'do': 'yarn install --frozen-lockfile'}
Plug 'neoclide/coc-html', {'do': 'yarn install --frozen-lockfile'}
Plug 'neoclide/coc-prettier', {'do': 'yarn install --frozen-lockfile'}
Plug 'neoclide/coc-snippets', {'do': 'yarn install --frozen-lockfile'}
Plug 'neoclide/coc-json' , {'do': 'yarn install --frozen-lockfile'}
"Plug 'hexh250786313/coc-pretty-ts-errors', {'do': 'yarn install --frozen-lockfile'}
"Plug 'hexh250786313/coc-copilot', {'do': 'yarn install --frozen-lockfile'}

" CocInstall @hexuhua/coc-copilot


call plug#end()


" Leader {{{
let mapleader = ","
"}}}
"
"
" 'folke/which-key.nvim' {{{
lua << EOF
local ok, wk = pcall(require, "which-key")
if ok then
  wk.setup()
  wk.add({
    { "<leader>f", group = "file" },
    { "<leader>b", group = "buffer", desc = "Buffer" },
    { "<leader>bd", desc = "Delete buffer" },
    { "<leader>bn", desc = "Next buffer" },
    { "<leader>bp", desc = "Prev buffer" },
    { "<leader>bi", desc = "Toggle pin" },
    { "<leader>bg", desc = "Pick buffer" },
    { "<leader>m", group = "markdown" },
    { "<leader>mv", desc = "Toggle markdown preview" },
    { "<leader>ms", desc = "Toggle markdown split preview" },
    { "<leader>cheat", desc = "Show cheatsheet" },
  })
end
EOF
" }}


" nvim-telescope/telescope.nvim {{{
lua << EOF
local function file_browser_cd_and_close(prompt_bufnr)
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local entry = action_state.get_selected_entry()
  if not entry or not entry.Path then
    return
  end

  local path = entry.Path
  local target = path:is_dir() and path:absolute() or path:parent():absolute()
  vim.cmd("cd " .. vim.fn.fnameescape(target))
  actions.close(prompt_bufnr)
  vim.notify("cwd: " .. target, vim.log.levels.INFO)
end

local function open_file_browser()
  local path = vim.fn.expand("%:p:h")
  if path == "" then
    path = vim.loop.cwd()
  end

  require("telescope").extensions.file_browser.file_browser({
    path = path,
    select_buffer = true,
    prompt_path = true,
  })
end

vim.keymap.set("n", "<leader>fs", open_file_browser, { desc = "File browser" })

require('telescope').setup {
  defaults = {

    selection_strategy = "reset",
    sorting_strategy = "descending",
    scroll_strategy = "cycle",
    color_devicons = true,

    file_previewer = require("telescope.previewers").vim_buffer_cat.new,
    grep_previewer = require("telescope.previewers").vim_buffer_vimgrep.new,
    qflist_previewer = require("telescope.previewers").vim_buffer_qflist.new,
    file_ignore_patterns = {
      "node_modules"
    }

  },
  extensions = {
    file_browser = {
      mappings = {
        i = {
          ["<C-t>"] = file_browser_cd_and_close,
        },
        n = {
          ["t"] = file_browser_cd_and_close,
        },
      },
    },
    fzf = {
      theme = "dropdown",
      fuzzy = true,
      override_generic_sorter = false,
      override_file_sorter = true,
      case_mode = "smart_case"
    },
    ["ui-select"] = {
      require("telescope.themes").get_dropdown {
        -- even more opts
      },
    }
  },
  pickers = {
    buffers = {
      show_all_buffers = true,
      sort_lastused = true,
      -- theme = "dropdown",
      -- previewer = false,
      mappings = {
        i = {
          ["<M-d>"] = "delete_buffer",
          ["<C-d>"] = "delete_buffer",
          ["<Esc>"] = "close",
          ["<C-j>"] = "move_selection_next",
          ["<C-k>"] = "move_selection_previous",
        }
      }
    }
  },
}
local telescope_ok, telescope = pcall(require, 'telescope')
if telescope_ok then
  pcall(function() telescope.load_extension('fzf') end)
  pcall(function() telescope.load_extension('file_browser') end)
  pcall(function() telescope.load_extension('harpoon') end)
  pcall(function() telescope.load_extension('env') end)
  pcall(function() telescope.load_extension('ui-select') end)
  pcall(function() telescope.load_extension('notify') end)
end
EOF


" Files

nnoremap <leader>ff :lua require'telescope.builtin'.find_files{}<cr>
nnoremap <leader>fi :lua require'telescope.builtin'.find_files{ find_command = { "rg", "--no-ignore", "--files" } }<cr>
nnoremap <leader>fh :lua require'telescope.builtin'.find_files{ find_command = { "rg", "--hidden", "--files" } }<cr>

nnoremap <leader>fz :lua require('telescope.builtin').find_files({ find_command = { "rg", "--files", "--type", vim.fn.input("Type: ")} })<cr>

nnoremap <leader>fb <cmd>Telescope buffers<cr>
nnoremap <leader>fm <cmd>Telescope harpoon marks<cr>
" nnoremap <Leader>fs :lua require'telescope.builtin'.file_browser{ cwd = vim.fn.expand('%:p:h') }<cr>
nnoremap <Leader>gs :lua require'telescope.builtin'.git_status{}<cr>
nnoremap <Leader>gc :lua require'telescope.builtin'.git_commits{}<cr>
"nnoremap <Leader>cb :lua require'telescope.builtin'.git_branches{}<cr>
nnoremap <leader>fr :lua require'telescope.builtin'.resume{}<CR>
nnoremap <leader>fg <cmd>:lua require'telescope.builtin'.live_grep{}<cr>

nnoremap <space><space>d <cmd>:lua require'telescope.builtin'.diagnostics{}<cr>

" nnoremap <leader>fg <cmd>lua require('telescope.builtin').live_grep( { file_ignore_patterns = { '**/*.spec.js' } } )<cr>
" nnoremap <leader>fgi <cmd>lua require('telescope.builtin').live_grep( { file_ignore_patterns = { vim.fn.input("Ignore pattern > ") } } )<cr>
"nnoremap <leader>fgd :lua require'telescope.builtin'.live_grep{ search_dirs = { 'slices/admin' } }

nnoremap <leader>cheat :Cheatsheet<cr>

"}}}


" Custom dashboard {{{
lua << EOF
local dashboard = {}
local state_file = vim.fn.stdpath("state") .. "/dashboard-projects.json"
local line_projects = {}
local line_meta = {}
local saved_ui = nil

local header = {
  "███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗",
  "████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║",
  "██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║",
  "██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║",
  "██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║",
  "╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝",
  "",
  "                 [ @adinvadim ]                 ",
}

local function normalize_path(path)
  if not path or path == "" then
    return nil
  end
  path = vim.fn.fnamemodify(path, ":p")
  if path ~= "/" then
    path = path:gsub("/+$", "")
  end
  return path
end

local function read_state()
  local ok, lines = pcall(vim.fn.readfile, state_file)
  if not ok or not lines or #lines == 0 then
    return { projects = {}, hidden = {} }
  end

  local ok_json, data = pcall(vim.json.decode, table.concat(lines, "\n"))
  if not ok_json or type(data) ~= "table" then
    return { projects = {}, hidden = {} }
  end

  data.projects = type(data.projects) == "table" and data.projects or {}
  data.hidden = type(data.hidden) == "table" and data.hidden or {}
  return data
end

local function write_state(state)
  vim.fn.mkdir(vim.fn.fnamemodify(state_file, ":h"), "p")
  vim.fn.writefile(vim.split(vim.json.encode(state), "\n"), state_file)
end

local function project_root(file)
  file = normalize_path(file)
  if not file then
    return nil
  end

  local stat = vim.loop.fs_stat(file)
  if not stat then
    return nil
  end

  local dir = stat.type == "directory" and file or vim.fn.fnamemodify(file, ":h")
  local found = vim.fs.find(".git", { path = dir, upward = true, stop = vim.env.HOME })[1]
  return found and normalize_path(vim.fs.dirname(found)) or nil
end

local function add_project(path, opts)
  path = normalize_path(path)
  if not path or vim.fn.isdirectory(path) == 0 then
    return
  end

  local state = read_state()
  if opts and opts.unhide then
    state.hidden[path] = nil
  elseif state.hidden[path] then
    return
  end

  local now = os.time()
  local projects = {}
  table.insert(projects, { path = path, last = now })

  for _, item in ipairs(state.projects) do
    if item.path and normalize_path(item.path) ~= path then
      table.insert(projects, { path = normalize_path(item.path), last = item.last or 0 })
    end
  end

  table.sort(projects, function(a, b)
    return (a.last or 0) > (b.last or 0)
  end)

  state.projects = vim.list_slice(projects, 1, 25)
  write_state(state)
end

local function remove_project(path)
  path = normalize_path(path)
  local state = read_state()
  local projects = {}

  for _, item in ipairs(state.projects) do
    if normalize_path(item.path) ~= path then
      table.insert(projects, item)
    end
  end

  state.projects = projects
  if path then
    state.hidden[path] = true
  end
  write_state(state)
end

local function seed_from_oldfiles()
  vim.cmd("silent! rshada")
  local state = read_state()
  local seen = {}
  for _, item in ipairs(state.projects) do
    if item.path then
      seen[normalize_path(item.path)] = true
    end
  end

  local now = os.time()
  local changed = false
  for _, file in ipairs(vim.v.oldfiles or {}) do
    local root = project_root(file)
    if root and not seen[root] and not state.hidden[root] then
      table.insert(state.projects, { path = root, last = now - #state.projects })
      seen[root] = true
      changed = true
    end
  end

  table.sort(state.projects, function(a, b)
    return (a.last or 0) > (b.last or 0)
  end)
  state.projects = vim.list_slice(state.projects, 1, 25)

  if changed then
    write_state(state)
  end
end

local function recent_projects()
  seed_from_oldfiles()
  local state = read_state()
  local projects = {}
  for _, item in ipairs(state.projects) do
    local path = normalize_path(item.path)
    if path and not state.hidden[path] and vim.fn.isdirectory(path) == 1 then
      table.insert(projects, { path = path, last = item.last or 0 })
    end
  end
  table.sort(projects, function(a, b)
    return (a.last or 0) > (b.last or 0)
  end)
  return vim.list_slice(projects, 1, 9)
end

local function display_width(text)
  return vim.fn.strdisplaywidth(text)
end

local function truncate(text, width)
  if display_width(text) <= width then
    return text
  end
  return vim.fn.strcharpart(text, 0, math.max(1, width - 3)) .. "..."
end

local function pad(text, width)
  return text .. string.rep(" ", math.max(1, width - display_width(text)))
end

local function center(text, width)
  return string.rep(" ", math.max(0, math.floor((width - display_width(text)) / 2))) .. text
end

local function setup_highlights()
  local light = vim.o.background ~= "dark"
  local colors = light and {
    header = "#0F4AA0",
    title = "#1F2937",
    rule = "#8A94A6",
    index = "#9CA3AF",
    name = "#064E9B",
    path = "#5F6B7A",
    key = "#9A3412",
    hint = "#374151",
  } or {
    header = "#7AA2F7",
    title = "#C0CAF5",
    rule = "#565F89",
    index = "#6B7280",
    name = "#7DCFFF",
    path = "#9AA5CE",
    key = "#F6C177",
    hint = "#C0CAF5",
  }

  vim.api.nvim_set_hl(0, "CustomDashboardHeader", { fg = colors.header, bold = true })
  vim.api.nvim_set_hl(0, "CustomDashboardTitle", { fg = colors.title, bold = true })
  vim.api.nvim_set_hl(0, "CustomDashboardRule", { fg = colors.rule })
  vim.api.nvim_set_hl(0, "CustomDashboardIndex", { fg = colors.index })
  vim.api.nvim_set_hl(0, "CustomDashboardName", { fg = colors.name, bold = true })
  vim.api.nvim_set_hl(0, "CustomDashboardPath", { fg = colors.path })
  vim.api.nvim_set_hl(0, "CustomDashboardKey", { fg = colors.key, bold = true })
  vim.api.nvim_set_hl(0, "CustomDashboardHint", { fg = colors.hint })
end

local function apply_dashboard_ui()
  if not saved_ui then
    saved_ui = {
      laststatus = vim.o.laststatus,
      showtabline = vim.o.showtabline,
    }
  end
  vim.o.laststatus = 0
  vim.o.showtabline = 0
end

local function restore_dashboard_ui()
  if not saved_ui then
    return
  end
  vim.o.laststatus = saved_ui.laststatus
  vim.o.showtabline = saved_ui.showtabline
  saved_ui = nil
end

local function buf_is_empty(bufnr)
  return vim.api.nvim_buf_get_name(bufnr) == ""
    and vim.api.nvim_buf_line_count(bufnr) == 1
    and vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] == ""
end

local function selected_project()
  local bufnr = vim.api.nvim_get_current_buf()
  local line = vim.api.nvim_win_get_cursor(0)[1]
  return line_projects[bufnr] and line_projects[bufnr][line] or nil
end

local function project_lines()
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = {}
  for line, _ in pairs(line_projects[bufnr] or {}) do
    table.insert(lines, line)
  end
  table.sort(lines)
  return lines
end

local function project_cursor_col(bufnr, line)
  local data = line_meta[bufnr] and line_meta[bufnr][line]
  return data and data.name_start or 0
end

local function snap_project_cursor()
  local bufnr = vim.api.nvim_get_current_buf()
  if vim.bo[bufnr].filetype ~= "dashboard" then
    return
  end

  local line = vim.api.nvim_win_get_cursor(0)[1]
  if line_projects[bufnr] and line_projects[bufnr][line] then
    local col = project_cursor_col(bufnr, line)
    if vim.api.nvim_win_get_cursor(0)[2] ~= col then
      vim.api.nvim_win_set_cursor(0, { line, col })
    end
  end
end

local function jump_project(delta)
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = project_lines()
  if #lines == 0 then
    return
  end

  local current = vim.api.nvim_win_get_cursor(0)[1]
  local target = lines[1]
  if delta > 0 then
    for _, line in ipairs(lines) do
      if line > current then
        target = line
        break
      end
    end
  else
    target = lines[#lines]
    for index = #lines, 1, -1 do
      if lines[index] < current then
        target = lines[index]
        break
      end
    end
  end
  vim.api.nvim_win_set_cursor(0, { target, project_cursor_col(bufnr, target) })
end

local function open_project(kind)
  local item = selected_project()
  if not item then
    return
  end

  add_project(item.path, { unhide = true })
  vim.cmd("cd " .. vim.fn.fnameescape(item.path))
  restore_dashboard_ui()

  if kind == "browser" then
    require("telescope").extensions.file_browser.file_browser({
      path = item.path,
      cwd = item.path,
      prompt_path = true,
    })
  else
    require("telescope.builtin").find_files({ cwd = item.path })
  end
end

local function forget_project()
  local item = selected_project()
  if not item then
    return
  end
  remove_project(item.path)
  dashboard.open()
  vim.notify("forgot: " .. vim.fn.fnamemodify(item.path, ":t"), vim.log.levels.INFO)
end

local function refresh_projects()
  seed_from_oldfiles()
  dashboard.open()
end

local function close_dashboard()
  restore_dashboard_ui()
  if vim.api.nvim_buf_get_name(0) == "" then
    vim.cmd("enew")
  else
    vim.cmd("bdelete")
  end
end

function dashboard.open()
  local bufnr = vim.api.nvim_get_current_buf()
  if vim.bo[bufnr].filetype ~= "dashboard" and not buf_is_empty(bufnr) then
    vim.cmd("enew")
    bufnr = vim.api.nvim_get_current_buf()
  end

  vim.bo[bufnr].readonly = false
  vim.bo[bufnr].modifiable = true
  apply_dashboard_ui()
  setup_highlights()
  if not pcall(vim.api.nvim_buf_set_name, bufnr, "dashboard://Dashboard") then
    pcall(vim.api.nvim_buf_set_name, bufnr, "dashboard://Dashboard-" .. bufnr)
  end
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].filetype = "dashboard"
  vim.wo.number = false
  vim.wo.relativenumber = false
  vim.wo.signcolumn = "no"
  vim.wo.cursorline = false
  vim.wo.foldcolumn = "0"
  vim.wo.colorcolumn = ""

  local columns = vim.o.columns
  local panel = math.min(96, math.max(56, columns - 8))
  local prefix = string.rep(" ", math.max(0, math.floor((columns - panel) / 2)))
  local projects = recent_projects()
  local lines = {}
  local map = {}
  local meta = {}
  local first_project_line = nil
  local header_start = nil
  local header_end = nil
  local title_line = nil
  local rule_line = nil
  local hint_line = nil

  for _ = 1, math.max(1, math.floor(vim.o.lines * 0.08)) do
    table.insert(lines, "")
  end

  for _, line in ipairs(header) do
    table.insert(lines, prefix .. center(line, panel))
    header_start = header_start or #lines
    header_end = #lines
  end

  table.insert(lines, "")
  table.insert(lines, prefix .. "Recent projects")
  title_line = #lines
  table.insert(lines, prefix .. string.rep("─", panel))
  rule_line = #lines

  if #projects == 0 then
    table.insert(lines, prefix .. "No projects yet. Press r to rebuild from oldfiles.")
  else
    local name_width = 32
    local path_width = math.max(18, panel - name_width - 8)
    for index, item in ipairs(projects) do
      local name = truncate(vim.fn.fnamemodify(item.path, ":t"), name_width)
      local path = truncate(vim.fn.fnamemodify(item.path, ":~"), path_width)
      local line = string.format("%2d  %s%s", index, pad(name, name_width), path)
      table.insert(lines, prefix .. line)
      map[#lines] = item
      meta[#lines] = {
        index_start = #prefix,
        index_end = #prefix + 2,
        name_start = #prefix + 4,
        name_end = #prefix + 4 + name_width,
        path_start = #prefix + 4 + name_width,
      }
      first_project_line = first_project_line or #lines
    end
  end

  table.insert(lines, "")
  table.insert(lines, prefix .. "Enter open   f browser   d forget   r refresh   q close")
  hint_line = #lines

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  line_projects[bufnr] = map
  line_meta[bufnr] = meta

  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].modified = false

  local opts = { buffer = bufnr, silent = true, nowait = true }
  vim.keymap.set("n", "<CR>", function() open_project("files") end, opts)
  vim.keymap.set("n", "f", function() open_project("browser") end, opts)
  vim.keymap.set("n", "d", forget_project, opts)
  vim.keymap.set("n", "r", refresh_projects, opts)
  vim.keymap.set("n", "q", close_dashboard, opts)
  vim.keymap.set("n", "j", function() jump_project(1) end, opts)
  vim.keymap.set("n", "<Down>", function() jump_project(1) end, opts)
  vim.keymap.set("n", "k", function() jump_project(-1) end, opts)
  vim.keymap.set("n", "<Up>", function() jump_project(-1) end, opts)
  vim.keymap.set("n", "h", "<Nop>", opts)
  vim.keymap.set("n", "l", "<Nop>", opts)
  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = bufnr,
    callback = snap_project_cursor,
  })

  for line = header_start or 1, header_end or 0 do
    vim.api.nvim_buf_add_highlight(bufnr, -1, "CustomDashboardHeader", line - 1, 0, -1)
  end
  if title_line then
    vim.api.nvim_buf_add_highlight(bufnr, -1, "CustomDashboardTitle", title_line - 1, 0, -1)
  end
  if rule_line then
    vim.api.nvim_buf_add_highlight(bufnr, -1, "CustomDashboardRule", rule_line - 1, 0, -1)
  end

  for line, data in pairs(meta) do
    vim.api.nvim_buf_add_highlight(bufnr, -1, "CustomDashboardIndex", line - 1, data.index_start, data.index_end)
    vim.api.nvim_buf_add_highlight(bufnr, -1, "CustomDashboardName", line - 1, data.name_start, data.name_end)
    vim.api.nvim_buf_add_highlight(bufnr, -1, "CustomDashboardPath", line - 1, data.path_start, -1)
  end

  if hint_line then
    vim.api.nvim_buf_add_highlight(bufnr, -1, "CustomDashboardHint", hint_line - 1, 0, -1)
    local hint = lines[hint_line]:sub(#prefix + 1)
    for _, key in ipairs({ "Enter", "f", "d", "r", "q" }) do
      local start_col = hint:find(key, 1, true)
      if start_col then
        vim.api.nvim_buf_add_highlight(
          bufnr,
          -1,
          "CustomDashboardKey",
          hint_line - 1,
          #prefix + start_col - 1,
          #prefix + start_col - 1 + #key
        )
      end
    end
  end
  if first_project_line then
    local data = meta[first_project_line]
    vim.api.nvim_win_set_cursor(0, { first_project_line, data and data.name_start or 0 })
  end
end

vim.api.nvim_create_user_command("Dashboard", dashboard.open, { force = true })

vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
  callback = function(args)
    local root = project_root(vim.api.nvim_buf_get_name(args.buf))
    if root then
      add_project(root, { unhide = true })
    end
  end,
})

vim.api.nvim_create_autocmd({ "BufLeave", "BufWipeout" }, {
  callback = function(args)
    if vim.bo[args.buf].filetype == "dashboard" then
      restore_dashboard_ui()
    end
  end,
})

vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    vim.schedule(function()
      if vim.fn.argc() ~= 0 then
        return
      end
      if not buf_is_empty(0) then
        return
      end
      dashboard.open()
    end)
  end,
})
EOF
" }}}

" 'neoclide/coc.nvim' {{{
" Use tab for trigger completion with characters ahead and navigate.
" NOTE: Use command ':verbose imap <tab>' to make sure tab is not mapped by
" other plugin before putting this into your config.

let g:coc_disable_transparent_cursor = 1


"au FileType vue let b:coc_root_patterns = ['.git', '.env', 'package.json', 'tsconfig.json', 'jsconfig.json', 'vite.config.ts', 'vite.config.js', 'vue.config.js', 'nuxt.config.ts']
"autocmd Filetype vue setlocal iskeyword+=-


" Use <c-space> to trigger completion.
if has('nvim')
  inoremap <silent><expr> <c-space> coc#refresh()
else
  inoremap <silent><expr> <c-@> coc#refresh()
endif

inoremap <silent><expr> <TAB>
  \ coc#pum#visible() ? coc#_select_confirm() :
  \ coc#expandableOrJumpable() ?
  \ "\<C-r>=coc#rpc#request('doKeymap', ['snippets-expand-jump',''])\<CR>" :
  \ CheckBackSpace() ? "\<TAB>" :
  \ coc#refresh()

  function! CheckBackSpace() abort
    let col = col('.') - 1
    return !col || getline('.')[col - 1]  =~# '\s'
  endfunction

  let g:coc_snippet_next = '<tab>'

" Use `[g` and `]g` to navigate diagnostics
" Use `:CocDiagnostics` to get all diagnostics of current buffer in location list.
nmap <silent> [g <Plug>(coc-diagnostic-prev)
nmap <silent> ]g <Plug>(coc-diagnostic-next)

" GoTo code navigation.
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)

nmap <leader>h :call coc#float#has_float() ? coc#float#close_all() : CocActionAsync('doHover')<CR>

" Use K to show documentation in preview window.
nnoremap <silent> K :call <SID>show_documentation()<CR>

function! s:show_documentation()
  if (coc#float#has_float())
    call coc#float#close_all()
  endif
  if (index(['vim','help'], &filetype) >= 0)
    execute 'h '.expand('<cword>')
  elseif (coc#rpc#ready())
    call CocActionAsync('doHover')
  else
    execute '!' . &keywordprg . " " . expand('<cword>')
  endif
endfunction

" Hover docs and symbol references on cursor hold.
let g:coc_auto_hover = get(g:, 'coc_auto_hover', 1)

function! s:coc_on_hold() abort
  if &buftype !=# '' || &filetype ==# 'dashboard'
    return
  endif
  if !coc#rpc#ready()
    return
  endif
  silent call CocActionAsync('highlight')
  if g:coc_auto_hover && !coc#float#has_float()
    silent call CocActionAsync('doHover')
  endif
endfunction

augroup coc_hold_actions
  autocmd!
  autocmd CursorHold * call <SID>coc_on_hold()
augroup end

" Symbol renaming.
nmap <leader>rn <Plug>(coc-rename)

" Formatting selected code.
xmap <leader>f  <Plug>(coc-format-selected)
nmap <leader>f  <Plug>(coc-format-selected)

augroup mygroup
  autocmd!
  " Setup formatexpr specified filetype(s).
  autocmd FileType typescript,json setl formatexpr=CocAction('formatSelected')
  " Update signature help on jump placeholder.
  autocmd User CocJumpPlaceholder call CocActionAsync('showSignatureHelp')
augroup end

" Applying codeAction to the selected region.
" Example: `<leader>aap` for current paragraph
xmap <leader>a  <Plug>(coc-codeaction-selected)
nmap <leader>a  <Plug>(coc-codeaction-selected)

" Remap keys for applying codeAction to the current buffer.
nmap <leader>ac  <Plug>(coc-codeaction)
" Apply AutoFix to problem on the current line.
nmap <leader>qf  <Plug>(coc-fix-current)

" Run the Code Lens action on the current line.
nmap <leader>cl  <Plug>(coc-codelens-action)

" Map function and class text objects
" NOTE: Requires 'textDocument.documentSymbol' support from the language server.
xmap if <Plug>(coc-funcobj-i)
omap if <Plug>(coc-funcobj-i)
xmap af <Plug>(coc-funcobj-a)
omap af <Plug>(coc-funcobj-a)
xmap ic <Plug>(coc-classobj-i)
omap ic <Plug>(coc-classobj-i)
xmap ac <Plug>(coc-classobj-a)
omap ac <Plug>(coc-classobj-a)

" Remap <C-f> and <C-b> for scroll float windows/popups.
if has('nvim-0.4.0') || has('patch-8.2.0750')
  nnoremap <silent><nowait><expr> <C-f> coc#float#has_scroll() ? coc#float#scroll(1) : "\<C-f>"
  nnoremap <silent><nowait><expr> <C-b> coc#float#has_scroll() ? coc#float#scroll(0) : "\<C-b>"
  inoremap <silent><nowait><expr> <C-f> coc#float#has_scroll() ? "\<c-r>=coc#float#scroll(1)\<cr>" : "\<Right>"
  inoremap <silent><nowait><expr> <C-b> coc#float#has_scroll() ? "\<c-r>=coc#float#scroll(0)\<cr>" : "\<Left>"
  vnoremap <silent><nowait><expr> <C-f> coc#float#has_scroll() ? coc#float#scroll(1) : "\<C-f>"
  vnoremap <silent><nowait><expr> <C-b> coc#float#has_scroll() ? coc#float#scroll(0) : "\<C-b>"
endif



" Use CTRL-S for selections ranges.
" Requires 'textDocument/selectionRange' support of language server.
nmap <silent> <C-s> <Plug>(coc-range-select)
xmap <silent> <C-s> <Plug>(coc-range-select)

" Add `:Format` command to format current buffer.
command! -nargs=0 Format :call CocActionAsync('format')

" Add `:Fold` command to fold current buffer.
command! -nargs=? Fold :call     CocAction('fold', <f-args>)

" Add `:OR` command for organize imports of the current buffer.
command! -nargs=0 OR   :call     CocActionAsync('runCommand', 'editor.action.organizeImport')

" Add (Neo)Vim's native statusline support.
" NOTE: Please see `:h coc-status` for integrations with external plugins that
" provide custom statusline: lightline.vim, vim-airline.
set statusline^=%{coc#status()}%{get(b:,'coc_current_function','')}

" Mappings for CoCList
" Show all diagnostics.
nnoremap <silent><nowait> <space>a  :<C-u>CocList diagnostics<cr>
" Manage extensions.
nnoremap <silent><nowait> <space>e  :<C-u>CocList extensions<cr>
" Show commands.
nnoremap <silent><nowait> <space>c  :<C-u>CocList commands<cr>
" Find symbol of current document.
nnoremap <silent><nowait> <leader>o  :<C-u>CocList outline<cr>
" Search workspace symbols.
nnoremap <silent><nowait> <space>s  :<C-u>CocList -I symbols<cr>
" Do default action for next item.
nnoremap <silent><nowait> <space>j  :<C-u>CocNext<CR>
" Do default action for previous item.
nnoremap <silent><nowait> <space>k  :<C-u>CocPrev<CR>
" Resume latest coc list.
nnoremap <silent><nowait> <space>p  :<C-u>CocListResume<CR>
" }}}

" Move line {{{
" see https://vim.fandom.com/wiki/Moving_lines_up_or_down

nnoremap <A-j> :m .+1<CR>==
nnoremap <A-k> :m .-2<CR>==
inoremap <A-j> <Esc>:m .+1<CR>==gi
inoremap <A-k> <Esc>:m .-2<CR>==gi
vnoremap <A-j> :m '>+1<CR>gv=gv
vnoremap <A-k> :m '<-2<CR>gv=gv
" }}}


" Auto file type {{{

au BufRead,BufNewFile *.conf set filetype=dosini

" File type for terraform tpl files
au BufRead,BufNewFile *.yaml.tpl set filetype=yaml
au BufRead,BufNewFile *.yml.tpl set filetype=yaml
au BufRead,BufNewFile *.conf.tpl set filetype=dosini
au BufRead,BufNewFile *.sh.tpl set filetype=bash

" }}}

" Colors {{{
if (has("termguicolors"))
  set termguicolors " enable true colors support
endif

"let g:dracula_colorterm = 0
"let g:dracula_italic = 1


set textwidth=80
set colorcolumn=+1
set colorcolumn=80


" Auto-detect macOS dark/light mode and apply matching colorscheme {{{
lua << EOF
local function get_system_appearance()
  local handle = io.popen("defaults read -g AppleInterfaceStyle 2>/dev/null")
  if handle then
    local result = handle:read("*a")
    handle:close()
    if result and result:find("Dark") then
      return "dark"
    end
  end
  return "light"
end

local function apply_colorscheme()
  local appearance = get_system_appearance()
  if appearance == "dark" then
    vim.cmd("colorscheme nightfly")
    vim.o.background = "dark"
  else
    vim.cmd("colorscheme github_light_colorblind")
    vim.o.background = "light"
  end
end

-- Apply on startup
apply_colorscheme()

-- Watch for system appearance changes (macOS 10.14+)
vim.loop.new_timer():start(3000, 3000, vim.schedule_wrap(function()
  local new_bg = get_system_appearance()
  if new_bg ~= vim.g.system_appearance then
    vim.g.system_appearance = new_bg
    apply_colorscheme()
  end
end))
vim.g.system_appearance = get_system_appearance()
EOF
" }}}

"highlight Cursor guifg=#f00 guibg=#657b83
highlight Comment cterm=italic gui=italic

" Make it obvious where 80 characters is
" }}}


" norcalli/nvim-colorizer.lua {{
lua require'colorizer'.setup()
" }}}


" Plug 'karb94/neoscroll.nvim'{{{
lua require('neoscroll').setup()
" }}}

" 'akinsho/nvim-bufferline.lua' {{{
lua << EOF
vim.api.nvim_exec([[let $KITTY_WINDOW_ID=0]], true)
require("bufferline").setup{
  highlights = {
  },
  options = {
    modified_icon = "●",
    left_trunc_marker = "",
    right_trunc_marker = "",
    max_name_length = 25,
    max_prefix_length = 25,
    enforce_regular_tabs = false,
    view = "multiwindow",
    show_buffer_close_icons = true,
    show_close_icon = false,
    separator_style = "thin",
    diagnostics = "coc",
    diagnostics_update_in_insert = false,
    diagnostics_indicator = function(count, level, diagnostics_dict, context)
      return "("..count..")"
    end,
    custom_filter = function(bufnr)
      return vim.bo[bufnr].filetype ~= "dashboard"
    end,
    offsets = {
      {
        filetype = "coc-explorer",
        text = "File Explorer",
        highlight = "Directory",
        text_align = "center"
      }
    }
  }
}
EOF

nnoremap <leader>bi :BufferLineTogglePin<CR>
command! BufDeleteOnly silent! execute "%bd|e#|bd#"
nnoremap <leader>bD :BufDeleteOnly<CR>
nnoremap <silent> gb :BufferLinePick<CR>
nnoremap <leader>bg :BufferLinePick<CR>


" Only work if add this lines to kitty
" map ctrl+tab     send_text normal,application \x1b[9;5u
" map ctrl+shift+tab send_text normal,application \x1b[9;6u
nnoremap <silent> <C-TAB> :BufferLineCycleNext<CR>
nnoremap <silent> <C-S-TAB> :BufferLineCyclePrev<CR>
" }}}

" Mappings {{{

    " Next buffer
    nnoremap <leader>bn :<C-u>bn<CR>
    " Prev buffer
    nnoremap <leader>bp :<C-u>bp<CR>
    " Delete buffer without closing window
    nnoremap <silent><leader>bd :<C-u>bn<bar>sp<bar>bp<bar>bd<CR>
    nmap <leader>. <c-^>

    vnoremap <C-r> "hy:%s/<C-r>h//gc<left><left><left>

    imap <C-l> <Right>
    imap <C-h> <Left>
    imap <C-j> <Down>
    imap <C-k> <Up>

" }}}

" kyazdani42/nvim-tree.lua {{{

lua << EOF
local function my_on_attach(bufnr)
  local api = require('nvim-tree.api')
  local function opts(desc)
    return { desc = 'nvim-tree: ' .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
  end
  api.config.mappings.default_on_attach(bufnr)
  vim.keymap.set('n', 'u', api.tree.change_root_to_parent, opts('Up'))
end

require('nvim-tree').setup({
  on_attach = my_on_attach,
  sort_by = "case_sensitive",
  view = {
    adaptive_size = true,
  },
  renderer = {
    group_empty = true,
  },
  filters = {
  },
})
EOF

nnoremap <C-n> :NvimTreeToggle<CR>
nnoremap <leader>r :NvimTreeRefresh<CR>
nnoremap <leader>n <cmd>:NvimTreeFindFile<CR>
"}}}
"
"
"" nvim-treesitter {{{
lua <<EOF
local ok, configs = pcall(require, 'nvim-treesitter.configs')
if ok then
  configs.setup {
    ensure_installed = { 'html', 'javascript', 'typescript', 'tsx', 'css', 'json', 'vue', 'gitignore', 'markdown', 'markdown_inline' },
    auto_install = true,
    highlight = {
      enable = true,
      additional_vim_regex_highlighting = true
    },
    indent = {
      enable = false
    },
    context_commentstring = {
      enable = true
    }
  }
end
EOF
" }}}
"

" OXY2DEV/markview.nvim {{{
lua << EOF
local ok, markview = pcall(require, "markview")
if ok then
  markview.setup({
    preview = {
      icon_provider = "devicons",
    },
  })
end
EOF
nnoremap <leader>mv <cmd>Markview<CR>
nnoremap <leader>ms <cmd>Markview splitToggle<CR>
" }}}
"



" Plug 'nvim-lualine/lualine.nvim' {{{
lua << EOF
require('plenary.reload').reload_module('lualine', true)

local function modified()
  if vim.bo.modified then
    return '●'
  elseif vim.bo.modifiable == false or vim.bo.readonly == true then
    return '-'
  end
  return ''
end

require('lualine').setup({
  extensions = {
  },
  options = {
    globalstatus = true,
    component_separators = '',
    section_separators = '',
    disabled_filetypes = {
      winbar = {
        'dashboard',
        'NvimTree'
      }
    },
  },
  sections = {
    lualine_a = {'mode'},
    lualine_b = {
      'branch',
      {
        'diagnostics',
        sections = { 'error', },
      },
      {
        'diagnostics',
        sections = { 'warn', },
      },
    },
    lualine_c = {{ 'filename', path = 1, file_status = false }},
    lualine_x = {'encoding', 'fileformat', 'filesize', 'filetype'},
    lualine_y = {'progress'},
    lualine_z = {'location'}
  },
  winbar = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = {},
    lualine_x = {'diagnostics'},
    lualine_y = {'filetype'},
    lualine_z = {{ 'filename', file_status=false }, modified}
  },

  inactive_winbar = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = {},
    lualine_x = {},
    lualine_y = {},
    lualine_z = {{ 'filename', file_status=false }, modified}
  }

})

EOF
" }}}

" Plug 'windwp/nvim-autopairs' {{{
lua << EOF
require('nvim-autopairs').setup()
EOF
" }}}

" tpope/vim-commentary {{{
nnoremap <leader>/ :Commentary<CR>
vnoremap <leader>/ :Commentary<CR>
nnoremap <M-/> :Commentary<CR>
vnoremap <M-/> :Commentary<CR>
"}}}


" 'vim-test/vim-test' {{{
let test#strategy = "vimux"
let test#neovim#term_position = "vertical"
" let g:test#javascript#runner = 'jest'
" https://github.com/vim-test/vim-test/issues/272
let g:root_markers = ['package.json', '.git/']
function! s:RunVimTest(cmd)
    " I guess this part could be replaced by projectionist#project_root
    for marker in g:root_markers
        let marker_file = findfile(marker, expand('%:p:h') . ';')
        if strlen(marker_file) > 0
            let g:test#project_root = fnamemodify(marker_file, ":p:h")
            break
        endif
        let marker_dir = finddir(marker, expand('%:p:h') . ';')
        if strlen(marker_dir) > 0
            let g:test#project_root = fnamemodify(marker_dir, ":p:h")
            break
        endif
    endfor

    execute a:cmd
endfunction

nnoremap <leader>tt :call <SID>RunVimTest('TestNearest')<cr>
nnoremap <leader>tl :call <SID>RunVimTest('TestLast')<cr>
nnoremap <leader>tf :call <SID>RunVimTest('TestFile')<cr>
nnoremap <leader>ts :call <SID>RunVimTest('TestSuite')<cr>
nnoremap <leader>tv :call <SID>RunVimTest('TestVisit')<cr>

lua << EOF
local ok, wk = pcall(require, "which-key")
if ok then
  wk.add({
    { "<leader>t", group = "test" },
    { "<leader>tt", desc = "Test nearest" },
    { "<leader>tl", desc = "Test last" },
    { "<leader>tf", desc = "Test file" },
    { "<leader>ts", desc = "Test suite" },
    { "<leader>tv", desc = "Test visit" },
  })
end
EOF
" }}}
"

" Plug 'github/copilot.vim' {{{
imap <silent><script><expr> <C-B> copilot#Accept("\<CR>")
let g:copilot_no_tab_map = v:true

let g:copilot_filetypes = {
\ 'yaml': v:true,
\ }

" }}}


" ThePrimeagen/harpoon {{{
nnoremap <leader>a :lua require("harpoon.mark").add_file()<CR>
" nnoremap <leader>m :lua require("harpoon.ui").toggle_quick_menu()<CR>
nnoremap <leader>1 :lua require("harpoon.ui").nav_file(1)<CR>
nnoremap <leader>2 :lua require("harpoon.ui").nav_file(2)<CR>
nnoremap <leader>3 :lua require("harpoon.ui").nav_file(3)<CR>
nnoremap <leader>4 :lua require("harpoon.ui").nav_file(4)<CR>
" }}}

if $VEIL_NVIM !=# '1'
  " coder/claudecode.nvim {{{
  lua << EOF
local ok, claudecode = pcall(require, "claudecode")
if ok then
  claudecode.setup({
    terminal = {
      provider = "none",  -- No terminal in nvim, use external Claude Code
    },
  })
else
  -- Define no-op commands so keymaps don't error
  vim.api.nvim_create_user_command('ClaudeCodeSend', function() print("claudecode.nvim not installed") end, {})
  vim.api.nvim_create_user_command('ClaudeCodeTreeAdd', function() print("claudecode.nvim not installed") end, {})
end
EOF
  nnoremap <leader>cs :ClaudeCodeSend<CR>
  vnoremap <leader>cs :ClaudeCodeSend<CR>
  nnoremap <leader>ct :ClaudeCodeTreeAdd<CR>
  " }}}
endif



" from https://github.com/nicknisi/dotfiles/blob/main/config/nvim/plugin/zoom.vim
" Zoom into a pane, making it full screen (in a tab)
" This plugin is useful when working with multiple panes
" but temporarily needing to zoom into one to see more of
" the code from that buffer.
" Triggering the plugin again from the zoomed in tab brings it back
" to its original pane location
function s:Zoom()
    if winnr('$') > 1
        tab split
    elseif len(filter(map(range(tabpagenr('$')), 'tabpagebuflist(v:val + 1)'),
        \ 'index(v:val, ' . bufnr('') . ') >= 0')) > 1
        tabclose
    endif
endfunction

nnoremap <Plug>Zoom :<C-U>call <SID>Zoom()<cr>
nmap <leader>z <Plug>Zoom


" for command mode
vnoremap <Tab> >gv
vnoremap <S-Tab> <gv

" for insert mode
inoremap <S-Tab> <C-d>

nnoremap <M-s> :w<CR>

nnoremap <M-w> :bd<CR>

nnoremap <M-n> :enew<CR>


" Only work if add this line to kitty
" map cmd+, send_text normal,application \x1b[44;9u
nnoremap <M-,> :e ~/.config/nvim/init.vim<CR>

" 'kevinhwang91/nvim-ufo' {{{
lua << EOF
vim.o.foldcolumn = '1'
vim.o.foldlevel = 99
vim.o.foldlevelstart = 99
vim.o.foldenable = true

-- Using ufo provider need remap `zR` and `zM`. If Neovim is 0.6.1, remap yourself
local ufo_ok, ufo = pcall(require, 'ufo')
if ufo_ok then
  vim.keymap.set('n', 'zR', ufo.openAllFolds)
  vim.keymap.set('n', 'zM', ufo.closeAllFolds)
  ufo.setup()
else
  vim.keymap.set('n', 'zR', 'zr')
  vim.keymap.set('n', 'zM', 'zm')
end
EOF

" }}}

" 'nvim-pack/nvim-spectre' {{{

lua << EOF
local spectre_ok, spectre = pcall(require, 'spectre')
if spectre_ok then
  spectre.setup({ is_block_ui_break = true })
end

vim.keymap.set('n', '<leader>S', '<cmd>lua require("spectre").toggle()<CR>', {
    desc = "Toggle Spectre"
})
vim.keymap.set('n', '<leader>sw', '<cmd>lua require("spectre").open_visual({select_word=true})<CR>', {
    desc = "Search current word"
})
vim.keymap.set('v', '<leader>sw', '<esc><cmd>lua require("spectre").open_visual()<CR>', {
    desc = "Search current word"
})
vim.keymap.set('n', '<leader>sp', '<cmd>lua require("spectre").open_file_search({select_word=true})<CR>', {
    desc = "Search on current file"
})
EOF
" }}}
