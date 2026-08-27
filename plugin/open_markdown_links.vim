" plugin/open_markdown_links.vim
" Open the markdown link under the cursor in the browser (via open-browser.vim).
" Maintainer: Denis Rampnoux

if exists('g:loaded_open_markdown_links')
  finish
endif
let g:loaded_open_markdown_links = 1

let s:save_cpo = &cpo
set cpo&vim

command! -bar OpenMarkdownLink call open_markdown_links#open()

nnoremap <silent> <Plug>(open-markdown-link) :<C-u>call open_markdown_links#open()<CR>

let &cpo = s:save_cpo
unlet s:save_cpo
