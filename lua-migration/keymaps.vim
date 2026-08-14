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

" Put the original cursor position back into whatever the view currently is and
" report which screen line it lands on. winrestview() sets the cursor and the
" viewport independently, so 'scrolloff' cannot drag the cursor along - which is
" what let <C-E> walk the cursor off its line near the end of a buffer or past a
" tall wrapped line.
function! s:EyePin(save)
  let view = winsaveview()
  let view.lnum = a:save.lnum
  let view.col = a:save.col
  let view.coladd = a:save.coladd
  let view.curswant = a:save.curswant
  call winrestview(view)
  return winline()
endfunction

" Put the cursor line a quarter of the window down ("eye level"), the same way
" zz/zt/zb put it in the middle/top/bottom.
"
" Scrolls one step at a time and re-measures instead of firing a fixed number of
" <C-E> after zz. That fixed count assumed one <C-E> == one screen line and that
" the scroll always succeeds, which is false with 'wrap' on (without
" 'smoothscroll' a single <C-E> skips a whole wrapped line) and at the ends of
" the buffer, where the window is not fully covered by lines.
function! ScrollEye()
  let target = winheight(0) / 4 + 1
  let save = winsaveview()
  let guard = winheight(0) * 2

  let best = s:EyePin(save)
  let bestview = winsaveview()

  while guard > 0 && best != target
    let guard -= 1
    let from = [line('w0'), winsaveview().skipcol]
    execute 'normal! ' . (best > target ? "\<C-E>" : "\<C-Y>")

    " Nothing moved: top or bottom of the buffer, eye level is unreachable.
    if [line('w0'), winsaveview().skipcol] == from
      break
    endif

    " A wrapped line jumped us past eye level (or nowhere nearer to it): stop
    " and keep the closest view instead of oscillating around the target.
    let now = s:EyePin(save)
    if abs(now - target) >= abs(best - target)
      break
    endif

    let best = now
    let bestview = winsaveview()
  endwhile

  call winrestview(bestview)
endfunction

" z eye level
nnoremap <silent> ze <Cmd>call ScrollEye()<CR>
xnoremap <silent> ze <Cmd>call ScrollEye()<CR>

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
