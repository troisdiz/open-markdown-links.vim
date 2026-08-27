" Integration tests for open_markdown_links#open() and the plugin wiring.
" Uses test/fake-openbrowser/ as a stand-in for tyru/open-browser.vim.
" Run with: vim -u NONE -N -e -s -S test/test_open.vim

set nocompatible
let s:testdir = expand('<sfile>:p:h')
let s:root = fnamemodify(s:testdir, ':h')
execute 'set runtimepath^=' . s:testdir . '/fake-openbrowser'
execute 'set runtimepath^=' . s:root

runtime plugin/openbrowser.vim
runtime plugin/open_markdown_links.vim

let s:out = []
let s:fail = 0

function! s:run(name, lines, lnum, col, want) abort
  let g:captured = ''
  enew!
  call setline(1, a:lines)
  call cursor(a:lnum, a:col)
  OpenMarkdownLink
  if g:captured ==# a:want
    call add(s:out, 'ok   - ' . a:name)
  else
    let s:fail += 1
    call add(s:out, 'FAIL - ' . a:name . ' got=' . string(g:captured) . ' want=' . string(a:want))
  endif
endfunction

call s:run('command opens inline link',
      \ ['[x](http://example.com)'], 1, 2, 'http://example.com')
call s:run('command opens url with balanced parens',
      \ ['[Vim](https://en.wikipedia.org/wiki/Vim_(text_editor))'], 1, 30,
      \ 'https://en.wikipedia.org/wiki/Vim_(text_editor)')
call s:run('command resolves reference link',
      \ ['[x][ref]', '[ref]: http://ref.example.com'], 1, 3,
      \ 'http://ref.example.com')

" The <Plug> mapping drives the same code path.
let g:captured = ''
enew!
call setline(1, ['[y](http://plug.example.com)'])
call cursor(1, 2)
execute "normal \<Plug>(open-markdown-link)"
if g:captured ==# 'http://plug.example.com'
  call add(s:out, 'ok   - <Plug>(open-markdown-link) drives openbrowser')
else
  let s:fail += 1
  call add(s:out, 'FAIL - <Plug> path got=' . string(g:captured))
endif

" With the cursor off any markdown link, defer to <Plug>(openbrowser-open).
let g:fallback_called = 0
nnoremap <silent> <Plug>(openbrowser-open) :<C-u>let g:fallback_called = 1<CR>
enew!
call setline(1, ['see http://bare.example.com here'])
call cursor(1, 2)
let g:captured = ''
OpenMarkdownLink
if g:fallback_called && g:captured ==# ''
  call add(s:out, 'ok   - falls back to openbrowser-open when not on a md link')
else
  let s:fail += 1
  call add(s:out, 'FAIL - fallback: called=' . g:fallback_called . ' captured=' . string(g:captured))
endif

call writefile(s:out, '/dev/stdout')
if s:fail > 0 | cquit! | else | qall! | endif
