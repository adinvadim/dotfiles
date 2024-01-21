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
set undodir=~/.vim/undodir
set undofile
set incsearch
set termguicolors
set scrolloff=2
set noshowmode
set completeopt=menu,menuone,noselect
set signcolumn=yes
set number
set updatetime=50
set encoding=UTF-8
set clipboard+=unnamedplus " Copy paste between vim and everything else
set nojoinspaces " don't autoinsert two spaces after '.', '?', '!' for join command
set showcmd " extra info at end of command line
set wildignore+=*/node_modules/**
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

call plug#begin('~/.local/share/nvim/site/autoload')

" Dashboard

" UI
Plug 'glepnir/dashboard-nvim', { 'commit': 'a36b3232c98616149784f2ca2654e77caea7a522' }
Plug 'kyazdani42/nvim-web-devicons'
Plug 'nvim-lualine/lualine.nvim'
Plug 'akinsho/nvim-bufferline.lua', { 'tag': 'v3.*' }
Plug 'norcalli/nvim-colorizer.lua', { 'branch': 'color-editor' }
Plug 'karb94/neoscroll.nvim'
Plug 'folke/which-key.nvim'
Plug 'kyazdani42/nvim-tree.lua'
Plug 'nvim-lua/popup.nvim'
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim'
Plug 'LinArcX/telescope-env.nvim'
Plug 'nvim-telescope/telescope-fzf-native.nvim', { 'do': 'make' }
Plug 'nvim-telescope/telescope-file-browser.nvim'
Plug 'sudormrfbin/cheatsheet.nvim'
Plug 'ThePrimeagen/harpoon'


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


" Syntax
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
Plug 'posva/vim-vue'
Plug 'JoosepAlviste/nvim-ts-context-commentstring'
Plug 'delphinus/vim-firestore'
Plug 'hashivim/vim-terraform'
Plug 'github/copilot.vim'
Plug 'gaoDean/autolist.nvim'
Plug 'axelvc/template-string.nvim'
" Plug 'roobert/tailwindcss-colorizer-cmp.nvim'


" Coc
Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'yaegassy/coc-tailwindcss3', {'do': 'yarn install --frozen-lockfile'}
Plug 'yaegassy/coc-volar', {'do': 'yarn install --frozen-lockfile'}
Plug 'yaegassy/coc-volar-tools', {'do': 'yarn install --frozen-lockfile'}
Plug 'neoclide/coc-tsserver', {'do': 'yarn install --frozen-lockfile'}
Plug 'neoclide/coc-vetur', {'do': 'yarn install --frozen-lockfile'}
Plug 'neoclide/coc-html', {'do': 'yarn install --frozen-lockfile'}
Plug 'neoclide/coc-prettier', {'do': 'yarn install --frozen-lockfile'}
Plug 'neoclide/coc-snippets', {'do': 'yarn install --frozen-lockfile'}
Plug 'neoclide/coc-json' , {'do': 'yarn install --frozen-lockfile'}


call plug#end()


" Leader {{{
let mapleader = ","
"}}}
"
"
" 'folke/which-key.nvim' {{{
lua << EOF
local wk = require("which-key")

wk.setup()
wk.register({
  ["<leader>"] = {
    f = {
      name = "+file",
    },
    b = {
      name = "+buffer",
      d = "Delete buffer",
      n = "Next buffer",
      p = "Prev buffer",
      i = "Toggle pin",
      g = "Pick buffer"
    }
  },
  ["<leader>cheat"] = { name = "Show cheatsheet"}
})
EOF
" }}


" nvim-telescope/telescope.nvim {{{
lua << EOF
require('telescope').setup {
  defaults = {
    file_ignore_patterns = { "yarn.lock", "package-lock", "node_modules", "dist", "dump", ".git", ".DS_Store", "**/*.log" ,"*.log" }
  },
  extensions = {
    fzf = {
      theme = "dropdown",
      fuzzy = true,
      override_generic_sorter = false,
      override_file_sorter = true,
      case_mode = "smart_case"
    },
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
require('telescope').load_extension('fzf')
require("telescope").load_extension "file_browser"
require("telescope").load_extension('harpoon')
require('telescope').load_extension('env')
EOF

"nnoremap <leader>fg :lua require('telescope.builtin').grep_string( { search = vim.fn.input("Grep for > ") } )<cr>
nnoremap <leader>ff :lua require'telescope.builtin'.find_files{}<cr>
nnoremap <leader>fb <cmd>Telescope buffers<cr>
nnoremap <leader>fm <cmd>Telescope harpoon marks<cr>
" nnoremap <Leader>fs :lua require'telescope.builtin'.file_browser{ cwd = vim.fn.expand('%:p:h') }<cr>
nnoremap <leader>fs <cmd>lua require 'telescope'.extensions.file_browser.file_browser( { path = vim.fn.expand('%:p:h') } )<CR>
"nnoremap <Leader>fc :lua require'telescope.builtin'.git_status{}<cr>
"nnoremap <Leader>cb :lua require'telescope.builtin'.git_branches{}<cr>
nnoremap <leader>fr :lua require'telescope.builtin'.resume{}<CR>
nnoremap <leader>fg <cmd>:lua require'telescope.builtin'.live_grep{}<cr>
" nnoremap <leader>fg <cmd>lua require('telescope.builtin').live_grep( { file_ignore_patterns = { '**/*.spec.js' } } )<cr>
" nnoremap <leader>fgi <cmd>lua require('telescope.builtin').live_grep( { file_ignore_patterns = { vim.fn.input("Ignore pattern > ") } } )<cr>
"nnoremap <leader>fgd :lua require'telescope.builtin'.live_grep{ search_dirs = { 'slices/admin' } }

nnoremap <leader>cheat :Cheatsheet<cr>

"" nnoremap <leader>fh <cmd>Telescope help_tags<cr>
"}}}


" 'glephir/dashboard-nvim' {{{
let g:dashboard_default_executive ='telescope'

lua << EOF
local wk = require("which-key")

wk.register({
  ["<leader>"] = {
    s = {
      name = "+session",
      s = { "<cmd>SessionSave<cr>", "Save session" },
      l = { "<cmd>SessionLoad<cr>", "Load session" },
    }
  },
})
EOF
nnoremap <silent> <Leader>fh :DashboardFindHistory<CR>
nnoremap <silent> <Leader>ct :DashboardChangeColorscheme<CR>
"" nnoremap <silent> <Leader>nf :DashboardNewFile<CR>
let g:dashboard_custom_shortcut={
\ 'last_session'       : ', s l',
\ 'find_history'       : ', f h',
\ 'find_file'          : ', f f',
\ 'new_file'           : ', n f',
\ 'change_colorscheme' : ', c t',
\ 'find_word'          : ', f g',
\ 'book_marks'         : ', f m',
\ }
let s:header = [
    \ '███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗',
    \ '████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║',
    \ '██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║',
    \ '██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║',
    \ '██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║',
    \ '╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝',
    \ '',
    \ '                 [ @adinvadim ]                 ',
    \ ]
let s:footer = []
let g:dashboard_custom_header = s:header
let g:dashboard_custom_footer = s:footer
" }}}

" 'neoclide/coc.nvim' {{{
" Use tab for trigger completion with characters ahead and navigate.
" NOTE: Use command ':verbose imap <tab>' to make sure tab is not mapped by
" other plugin before putting this into your config.

let g:coc_disable_transparent_cursor = 1


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

" Highlight the symbol and its references when holding the cursor.
autocmd CursorHold * silent call CocActionAsync('highlight')

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

" colorscheme github_dark_high_contrast
" set background=dark " light or dark
" highlight ColorColumn guibg=#090c10

colorscheme github_light_colorblind
set background=light " light or dark


" set background=light
" colorscheme solarized
" let g:solarized_italic_comments = v:true
" let g:solarized_italic_keywords = v:true
" let g:solarized_italic_functions = v:true
" let g:solarized_italic_variables = v:false
" let g:solarized_contrast = v:true
" let g:solarized_borders = v:true

" colorscheme onebuddy
"

lua << EOF
--require('github-theme').setup({
--  theme_style = "dark_default", -- dark/dark_default/dimmed/light/light_default
--  function_style = "italic",
--  sidebars = {"qf", "vista_kind", "terminal", "packer"},
--  -- Change the "hint" color to the "orange" color, and make the "error" color bright red
--  colors = {hint = "orange", error = "#ff0000"}
--})
EOF

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
require('nvim-tree').setup({
  -- lsp_diagnostics = true,
  sort_by = "case_sensitive",
  view = {
    adaptive_size = true,
    mappings = {
      list = {
        { key = "u", action = "dir_up" },
      },
    },
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
require'nvim-treesitter.configs'.setup {
  ensure_installed = { 'html', 'javascript', 'typescript', 'tsx', 'css', 'json', 'vue', 'gitignore' },
  auto_install = true,
  -- ensure_installed = "all", -- or maintained
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
EOF
" }}}


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
let g:test#javascript#runner = 'jest'
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
local wk = require("which-key")

wk.register({
  ["<leader>"] = {
    t = {
      name = "+test",
      t = "Test nearest",
      l = "Test last",
      f = "Test file",
      s = "Test suite",
      v = "Test visit",
    },
  },
})
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

