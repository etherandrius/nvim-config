" Commands Rule {{{

" *.txt fiels are filetype human
augroup filetype
  autocmd BufNewFile,BufRead *.txt set filetype=human
augroup END
augroup filetype
  autocmd BufNewFile,BufRead *.class set filetype=java
augroup END

" Remember cursor position
augroup vimrc-remember-cursor-position
  autocmd!
  autocmd BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g`\"" | endif
augroup END

" quarter scroll
function! ScrollQ()
    let height=winheight(0)
    execute 'normal! ' . height/4 . "\<C-E>"
endfunction
nnoremap <silent> ze zz:call ScrollQ()<CR>" z eye level
vnoremap <silent> ze <C-c>zz:call ScrollQ()<CR>gv

" (aagg) Mon Oct  7 22:36:49 PDT 2019
" Change cursor shape between insert and normal mode in iTerm2.app
if $TERM_PROGRAM =~ "iTerm"
    let &t_SI = "\<Esc>]50;CursorShape=1\x7" " Vertical bar in insert mode
    let &t_EI = "\<Esc>]50;CursorShape=0\x7" " Block in normal mode
endif

" " easier source, flush
" if has('nvim')
" command! -nargs=0 Source :source ~/.config/nvim/init.lua
" else
" command -nargs=0 Source :source ~/.vimrc
" endif

" command! -nargs=0 Flush :NERDTreeRefreshRoot | :CommandTFlush
command! -nargs=0 Flush :NERDTreeRefreshRoot

" {{{ Fold
command! -nargs=0 FoldCloseAll :norm zM
command! -nargs=0 FoldOpenAll :norm zR
command! -nargs=0 FoldCloseAllOther :norm zMa<ESC>
" }}}

function! SynStack()
  if !exists("*synstack")
    return
  endif
  echo map(synstack(line('.'), col('.')), 'synIDattr(v:val, "name")')
endfunc


" }}}
" Test {{{

" Below shows how to copy all highlight groups into a buffer 1
" ':redir @1 | :hi | redir END'

command! -nargs=0 SlsLog :execute "normal! yyP%%i<CR><CR><ESC>V!jq<CR>%o<ESC>jV!slslog<CR>"

hi TabLineSel ctermfg=DarkGreen ctermbg=White

nnoremap <Left> B
nnoremap <Right> E
vnoremap <Left> B
vnoremap <Right> E

nnoremap <Up> gT
nnoremap <Down> gt

" (aagg) Fri 14 May 2021 00:42:12 BST
nnoremap <silent> <space>p "0p
vnoremap <silent> <space>p "0p

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
