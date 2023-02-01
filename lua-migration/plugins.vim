" {{{ fzf
let $FZF_DEFAULT_COMMAND = 'rg --files --hidden --no-ignore --glob "!.git/*" --glob "!changelog" --glob "!vendor"'
if exists('g:neovide')
    let $FZF_PREVIEW_COMMAND = 'highlight -O ansi --style=solarized-light -l {} || cat {}'
else   
    let $FZF_PREVIEW_COMMAND = 'highlight -O ansi -l {} || cat {}'
endif

let g:fzf_preview_window = ['up:50%', 'ctrl-/']

" nmap <leader>b :BLines<CR>
" nmap <leader>T :Files<CR>
" nmap <leader>t :GFiles<CR>
nmap <leader>rh :History<CR>
" nmap <leader>rb :Buffers<CR>

function! RipgrepFzf(query, fullscreen)
  let command_fmt = 'rg --column --line-number --no-heading --color=always --smart-case --glob !"changelog" --glob "!vendor" -- %s || true'
  let initial_command = printf(command_fmt, shellescape(a:query))
  let reload_command = printf(command_fmt, '{q}')
  let spec = {'options': ['--phony', '--query', a:query, '--bind', 'change:reload:'.reload_command]}
  call fzf#vim#grep(initial_command, 1, fzf#vim#with_preview(spec), a:fullscreen)
endfunction

function! RipgrepFzfNoTest(query, fullscreen)
  let command_fmt = 'rg --column --line-number --no-heading --color=always --smart-case --glob "!changelog" --glob "!vendor" --glob "!*_test.go" --glob "!*Test.java" -- %s || true'
  let initial_command = printf(command_fmt, shellescape(a:query))
  let reload_command = printf(command_fmt, '{q}')
  let spec = {'options': ['--phony',  '--query', a:query, '--bind', 'change:reload:'.reload_command]}
  call fzf#vim#grep(initial_command, 1, fzf#vim#with_preview(spec), a:fullscreen)
endfunction

command! -nargs=* -bang RGnotest call RipgrepFzfNoTest(<q-args>, <bang>0)
nmap <leader>rg :RGnotest!<CR>
vmap <leader>rg y:RGnotest! <C-r>0<CR>

command! -nargs=* -bang RG call RipgrepFzf(<q-args>, <bang>0)
nmap <leader>Rg :RG!<CR>
vmap <leader>Rg y:RG! <C-r>0<CR>

lua << EOF
    local actions = require "fzf-lua.actions"
    require'fzf-lua'.setup {
    }
EOF
command! -nargs=0 Experiment :FzfLua live_grep

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
