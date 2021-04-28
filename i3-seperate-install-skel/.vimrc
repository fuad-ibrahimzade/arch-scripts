syntax off
inoremap <C-s> <esc>:w<cr>                 " save files2 nnoremap <C-s> :w<cr> 
inoremap <C-d> <esc>:wq!<cr>               " save and exit
nnoremap <C-d> :wq!<cr>
inoremap <C-q> <esc>:qa!<cr>               " quit discarding changes
nnoremap <C-q> :qa!<cr>
" FIX: ssh from wsl starting with REPLACE mode
" https://stackoverflow.com/a/11940894
if $TERM =~ 'xterm-256color'
    set noek
endif
:set number relativenumber
set nocompatible