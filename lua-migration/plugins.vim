" {{{ MultipleSearch
" one liner for all the colours
" for i in {0..255} ; do
"     printf "\x1b[48;5;%sm%3d\e[0m " "$i" "$i"
"     if (( i == 15 )) || (( i > 15 )) && (( (i-15) % 6 == 0 )); then
"         printf "\n";
"     fi
" done

let g:MultipleSearchTextColorSequence = "black,black,black,black,black,black,black"
let g:MultipleSearchColorSequence = "#ffffaf,#d7ff87,#ffffff,#ffd7ff,#afffaf,#ffd7af,#d7ffff"
let g:MultipleSearchMaxColors = 7
" let g:MultipleSearchColorSequence = "229,192,231,225,157,223,195"
" if exists('g:neovide')
" else
" endif
command! -nargs=0 Noh :noh | :SearchReset
" }}}
" {{{ NERDtree
autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif
nnoremap \tt :NERDTreeToggle<cr> " tree toggle 
nnoremap \tf :NERDTreeFind<cr>   " tree find
nnoremap \tg :NERDTreeFocus<cr>  " tree go 

let NERDTreeShowHidden=1

" }}}
" {{{ netrw
    let g:netrw_altfile = 1
" }}}
" {{{ brightest

augroup custom_highlight
  autocmd!
  au ColorScheme * highlight BrightestCustom guifg=#d33682 guibg=#f8e2d9
augroup END
let g:brightest#highlight = {"group" : "BrightestCustom"}

" }}}
" {{{ vim-fugitive rhubarb
let g:github_enterprise_urls = ['https://github.palantir.build']
" }}}
" vim: set foldmethod=marker: set foldlevel=0
