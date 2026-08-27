" Test double for open-browser.vim: capture the URL instead of opening a browser.
function! openbrowser#open(url) abort
  let g:captured = a:url
endfunction
