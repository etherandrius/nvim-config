
syntax on
set background=light
if has("gui_running") || exists('g:neovide')
    colorscheme solarized
else
  set t_Co=256
  let g:solarized_termcolors=16
  colorscheme solarized
endif
