" {{{ telescope
" Find files using Telescope command-line sugar.

" Using Lua functions
nnoremap <leader>t <cmd>lua require('telescope.builtin').git_files()<cr>

nnoremap <leader>T <cmd>lua require('telescope.builtin').find_files({find_command = {'rg', '--files', '--no-ignore', '--glob', '!*.class'}})<cr>
nnoremap <leader>b <cmd>lua require('telescope.builtin').current_buffer_fuzzy_find({previewer=false})<cr>
nnoremap z= <cmd>lua require('telescope.builtin').spell_suggest()<cr>
nnoremap <leader>rb <cmd>lua require('telescope.builtin').buffers()<cr>



" nnoremap <leader>fg <cmd>lua require('telescope.builtin').live_grep({vimgrep_arguments = { 'rg', '--color=never', '--no-heading', '--with-filename', '--line-number', '--column', '--smart-case', '-u' }})<cr>
" nnoremap <leader>rh <cmd>lua require('telescope.builtin').oldfiles()<cr>

" }}}
" {{{ MultipleSearch
" one liner for all the colours
" for i in {0..255} ; do
"     printf "\x1b[48;5;%sm%3d\e[0m " "$i" "$i"
"     if (( i == 15 )) || (( i > 15 )) && (( (i-15) % 6 == 0 )); then
"         printf "\n";
"     fi
" done

let g:MultipleSearchTextColorSequence = "black,black,black,black,black,black,black"
let g:MultipleSearchMaxColors = 7
if exists('g:neovide')
    let g:MultipleSearchColorSequence = "#ffffaf,#d7ff87,#ffffff,#ffd7ff,#afffaf,#ffd7af,#d7ffff"
else
    let g:MultipleSearchColorSequence = "229,192,231,225,157,223,195"
endif
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
hi BrightestCustom cterm=bold,underline ctermfg=DarkGrey guifg=Blue guibg=Yellow
let g:brightest#highlight = {"group" : "BrightestCustom"}

" }}}
" {{{ targets
" I don't know what the below mappings mean but they make argument targets more comfortable
let g:targets_seekRanges = 'cc cr cb cB lc ac Ac lr lb ar ab lB Ar aB Ab AB rr ll rb al rB Al bb aa bB Aa BB AA'
let g:targets_aiAI = 'aIAi'
" }}}
" {{{ harpoon

" nnoremap <leader>rm :Telescope harpoon marks theme=dropdown width=160<cr>
command! -nargs=0 HarpoonAddFile :lua require("harpoon.mark").add_file()
command! -nargs=0 HarpoonList :lua require("harpoon.ui").toggle_quick_menu()

hi! link HarpoonWindow Normal
hi! link HarpoonBorder Normal
" }}}
" vim: set foldmethod=marker: set foldlevel=0
