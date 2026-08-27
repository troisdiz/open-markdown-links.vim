" Test double for open-browser.vim: sets the load guard like the real plugin.
if exists('g:loaded_openbrowser') | finish | endif
let g:loaded_openbrowser = 1
