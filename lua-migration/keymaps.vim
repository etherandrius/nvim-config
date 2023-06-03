nmap Q <Nop>

" (aagg) jumping to functions
nmap gf ]]<ESC>V/\%V[a-zA-Z](<CR><ESC>:noh<CR>B
nmap gF k[[<ESC>V/\%V[a-zA-Z](<CR><ESC>:noh<CR>B

" (aagg) Wed Feb Wed May 31 22:37:23 BST 2023
" These are needed here for quickfix file navigation
nmap <C-n> :cn<CR>
nmap <C-p> :cp<CR>
nmap <C-N> :cn<CR>zz
nmap <C-P> :cp<CR>zz

" stay in the Visual mode when using shift commands
xnoremap < <gv
xnoremap > >gv

"making C-c be identical to <Esc>
inoremap <C-c> <Esc><Esc>
nnoremap <C-c> <Esc><Esc>
vnoremap <C-c> <Esc><Esc>

"insert a line below with out entering INSERT mode.  nnoremap <C-o> o<Esc> 
" <leader>d deletes current buffer and keeps the split
nnoremap <silent> <leader>d :lclose<bar>b#<bar>bd #<CR>

" <leader>n next tab
nnoremap <silent> <leader>n :tabn<CR>  
nnoremap <silent> <leader>N :tabp<CR>  

" " <leader>n next buffer
" nnoremap <silent> <leader>n :bn<CR>  
" nnoremap <silent> <leader>N :bp<CR>  

"making shift tab work as backwards tab.
inoremap <S-Tab> <C-d>
"making tab work in visual mode.
vmap <Tab> >
vmap <S-Tab> <

" search for <++> and enter INSERT mode, careful about changing this it's used
" all over the place.
nmap <Space><Space> <Esc>h/<++><CR>:noh<CR>"_c4l

" have Y behave analogously to D and C rather than to dd and cc (which is
" already done by yy):
nnoremap Y y$
" have U behave analogously to D and C rather than to dd and cc
nnoremap U <C-r>

" more comfortable split resizing
nnoremap <silent> + :vertical resize +3<CR>
nnoremap <silent> = :vertical resize +3<CR>
nnoremap - :vertical resize -3<CR>
nnoremap < :resize -1<CR>
nnoremap > :resize +1<CR>
" make K act analogous to J
nnoremap K kJ
vnoremap K kJ

nnoremap ; :
vnoremap ; :

" show trailing white space and tabs
nmap <F2> :set invlist list?<CR>

" Copy to clipboard
noremap <leader>y "*y

" search for highlighted text with *
vnoremap * y/\V<C-R>=escape(@",'/\')<CR><CR>

nnoremap <C-w><C-c> <Nop>
nnoremap <C-w>c <Nop>
nnoremap <C-w>C <Nop>

nnoremap <leader>l <C-w>l
nnoremap <leader>L <C-w>L
nnoremap <leader>k <C-w>k
nnoremap <leader>K <C-w>K
nnoremap <leader>j <C-w>j
nnoremap <leader>J <C-w>J
nnoremap <leader>h <C-w>h
nnoremap <leader>H <C-w>H

