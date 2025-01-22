" Basic remaps {{{

nmap Q <Nop>

nnoremap <Up> gT
nnoremap <Down> gt

nnoremap <Left> B
nnoremap <Right> E
vnoremap <Left> B
vnoremap <Right> E

" (aagg) Sat Sep  7 00:01:56 BST 2024
nnoremap zl zL
nnoremap zh zH
nnoremap zL zl
nnoremap zH zh

" (aagg) Fri 14 May 2021 00:42:12 BST
nnoremap <silent> <space>p "0p
vnoremap <silent> <space>p "0p

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
" (aagg) Sat Nov  9 03:43:54 PM GMT 2024
if has('macunix')
    noremap <leader>y "*y
else
    noremap <leader>y "+y
endif

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

" }}}
" ZE - z eye level (like zz, zt, zb) {{{

" quarter scroll
function! ScrollQ()
    let height=winheight(0)
    execute 'normal! ' . height/4 . "\<C-E>"
endfunction
nnoremap <silent> ze zz:call ScrollQ()<CR>" z eye level
vnoremap <silent> ze <C-c>zz:call ScrollQ()<CR>gv

" }}}
" Indent based navigation {{{

" Jump to the next or previous line that has the same level or a lower
" level of indentation than the current line.
"
" exclusive (bool): true: Motion is exclusive
" false: Motion is inclusive
" fwd (bool): true: Go to next line
" false: Go to previous line
" lowerlevel (bool): true: Go to line with lower indentation level
" false: Go to line with the same indentation level
function! NextIndent(exclusive, fwd, lowerlevel)
  let line = line('.')
  let column = col('.')
  let ogLine = line('.')
  let ogColumn = col('.')
  let lastline = line('$')
  let indent = indent(line)
  let stepvalue = a:fwd ? 1 : -1

  if (line > 0 && line <= lastline)
    let line = line + stepvalue
    if ( ! a:lowerlevel && indent(line) == indent || a:lowerlevel && indent(line) < indent)
        if (strlen(getline(line)) > 0)
          if (a:exclusive)
            let line = line - stepvalue
          endif
          exe line
          exe "normal " column . "|"
          return
        endif
    endif
  endif

  " adds the current position to the jump list
  normal! m`
  call cursor(ogLine, ogColumn)

  while (line > 0 && line <= lastline) " && (indent <= indent(line) || (indent(line) == 0 && strlen(getline(line)) == 0) ))
    let line = line + stepvalue
    if ( ! a:lowerlevel && indent(line) == indent || a:lowerlevel && indent(line) < indent)
      if (strlen(getline(line)) > 0)
        if (a:exclusive)
          let line = line - stepvalue
        endif
        exe line
        exe "normal " column . "|"
        return
      endif
    endif
  endwhile
endfunction

" Moving back and forth between lines of same or lower indentation.
noremap <silent> <C-h> :call NextIndent(0, 0, 1)<CR>
noremap <silent> <C-k> :call NextIndent(0, 0, 0)<CR>
noremap <silent> <C-j> :call NextIndent(0, 1, 0)<CR>
vnoremap <silent> <C-h> <Esc>:call NextIndent(0, 0, 1)<CR>m'gv''
vnoremap <silent> <C-k> <Esc>:call NextIndent(0, 0, 0)<CR>m'gv''
vnoremap <silent> <C-j> <Esc>:call NextIndent(0, 1, 0)<CR>m'gv''

" }}}
" vim: set foldmethod=marker: set foldlevel=0
