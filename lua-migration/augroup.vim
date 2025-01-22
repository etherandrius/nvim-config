
" *.txt fiels are filetype human
augroup filetype
  autocmd BufNewFile,BufRead *.class set filetype=java
augroup END

" Remember cursor position
augroup vimrc-remember-cursor-position
  autocmd!
  autocmd BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g`\"" | endif
augroup END
