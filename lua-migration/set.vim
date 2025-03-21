
set updatetime=250

set signcolumn=yes

set breakindent

" Considers - inside a word to be a part of the word. fake-word
set iskeyword+=-

" enables scrolling with mouse
set mouse=a

" setting default text width
set textwidth=120

" adjusting format options to my liking
" :help fo-table for letter meanings.
set formatoptions=crqlt
set formatoptions-=o 

set foldenable
set foldopen-=block " jumping with {  } will no longer open folds
" this breaks telescope think about using their provided autocms stuff
" augroup remember_folds
"   autocmd!
"   autocmd BufWinLeave * mkview
"   autocmd BufWinEnter * silent! loadview
" augroup END
" automatic fold column
set fdc=auto:7
" remove annoying dots when lines are folded
set fillchars+=fold:\ 

set number 
set relativenumber

" make searches case-insensitive, unless they contain upper-case letters:
set ignorecase
set smartcase

" assume the /g flag on :s substitutions to replace all matches in a line:
set gdefault

" expands every tab into spaces.
set expandtab

" tab length is equal to 4 spaces.
set tabstop=4
set shiftwidth=4

set history=50

" have the h and l cursor keys wrap between lines (like <Space> and <BkSpc> do
" by default), and ~ covert case over line breaks; also have the cursor keys
" wrap in insert mode:
set whichwrap=h,l,~,[,]

" shows the last command entered.
set showmode
set showcmd 

" lines don't wrap if the window is too small
set nowrap

" highlights the current line.
set cursorline

" shows what <C-n> can autocomplete.
set wildmenu

" options for autocomplete
set completeopt=menu,preview,noselect,menuone
set complete=.,w,b,u,t,i,kspell

" 
syntax spell notoplevel

" highlights search
set hlsearch
set incsearch

"leaves n lines between cursor and end of the screen
set scrolloff=5
set sidescrolloff=10
set sidescroll=1

"saves marks and jumps for the most recent 1000files, limits each file size to
"1000 lines.
set viminfo='1000,f1,<2000

set colorcolumn=81,101,121

" use "[RO]" for "[readonly]" to save space in the message line:
set shortmess+=r

" when using list, keep tabs at their full width and display `arrows':
execute 'set listchars+=tab:' . nr2char(187) . nr2char(183) . ',trail:' . nr2char(183)
set listchars+=extends:❯,precedes:❮,nbsp:␣
" (Character 187 is a right double-chevron, and 183 a mid-dot.)

set noswapfile

" keep a persistent undo file.
set undofile
set undodir=~/.vim/undo//

" eol - allows to delete end of line character with delete
" start - allows to delete all text, not just the one local to this INSERT
" mode instance.
set backspace=indent,eol,start

"DiagnosticHint is invisible by default
hi! link DiagnosticHint DiagnosticInfo

" better colors for matched parenthesis 
hi MatchParen gui=bold guibg=none guifg=black

" allow file custom settings. See bottom of this file for example
set modeline
