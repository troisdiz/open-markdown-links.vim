" Headless test runner for open_markdown_links#extract()
" Run with: vim -u NONE -N -e -s -S test/test_extract.vim
" Exits 0 if all pass, 1 (via cquit) if any fail.

set nocompatible
let s:root = expand('<sfile>:p:h:h')
execute 'set runtimepath^=' . s:root

let s:failures = 0
let s:count = 0
let s:out = []

function! s:check(name, lines, lnum, col, want) abort
  let s:count += 1
  let l:got = ''
  try
    let l:got = open_markdown_links#extract(a:lines, a:lnum, a:col)
  catch
    let l:got = 'ERROR: ' . v:exception
  endtry
  if l:got ==# a:want
    call add(s:out, 'ok   - ' . a:name)
  else
    let s:failures += 1
    call add(s:out, 'FAIL - ' . a:name)
    call add(s:out, '         got:  ' . string(l:got))
    call add(s:out, '         want: ' . string(a:want))
  endif
endfunction

" --- Inline links: cursor on label vs on destination ---
call s:check('inline, cursor on label',
      \ ['[label](http://example.com)'], 1, 3, 'http://example.com')
call s:check('inline, cursor on url',
      \ ['[label](http://example.com)'], 1, 12, 'http://example.com')
call s:check('inline, cursor on opening bracket',
      \ ['[label](http://example.com)'], 1, 1, 'http://example.com')
call s:check('inline, cursor on closing paren',
      \ ['[label](http://example.com)'], 1, 27, 'http://example.com')

" --- Title stripping ---
call s:check('inline with double-quoted title',
      \ ['[x](http://example.com "Title here")'], 1, 2, 'http://example.com')
call s:check('inline with single-quoted title',
      \ ["[x](http://example.com 'Title here')"], 1, 2, 'http://example.com')

" --- Balanced parentheses in the URL ---
call s:check('wikipedia trailing-paren url, cursor on url',
      \ ['[Vim](https://en.wikipedia.org/wiki/Vim_(text_editor))'], 1, 30,
      \ 'https://en.wikipedia.org/wiki/Vim_(text_editor)')
call s:check('wikipedia trailing-paren url, cursor on label',
      \ ['[Vim](https://en.wikipedia.org/wiki/Vim_(text_editor))'], 1, 2,
      \ 'https://en.wikipedia.org/wiki/Vim_(text_editor)')
call s:check('nested balanced parens',
      \ ['[a](http://x.com/a(b(c)d)e)'], 1, 2, 'http://x.com/a(b(c)d)e')

" --- Square brackets in the URL ---
call s:check('ipv6 bracket url',
      \ ['[home](http://[::1]:8080/)'], 1, 3, 'http://[::1]:8080/')
call s:check('bracket in query string',
      \ ['[q](https://x.com/?a[]=1)'], 1, 2, 'https://x.com/?a[]=1')

" --- Angle-bracket destinations ---
call s:check('angle-bracket url with spaces',
      \ ['[x](<http://example.com/a b>)'], 1, 2, 'http://example.com/a b')
call s:check('angle-bracket url with parens inside',
      \ ['[x](<http://x.com/(a)>)'], 1, 2, 'http://x.com/(a)')
call s:check('angle-bracket url with title',
      \ ['[x](<http://x.com/a> "t")'], 1, 2, 'http://x.com/a')

" --- Escaped delimiters ---
call s:check('escaped closing paren does not terminate url',
      \ ['[x](http://x.com/a\)b)'], 1, 2, 'http://x.com/a)b')
call s:check('escaped brackets in url',
      \ ['[x](http://x.com/\[a\])'], 1, 2, 'http://x.com/[a]')

" --- Multiple links on one line ---
call s:check('two links, cursor in first',
      \ ['[a](http://a.com) and [b](http://b.com)'], 1, 2, 'http://a.com')
call s:check('two links, cursor in second',
      \ ['[a](http://a.com) and [b](http://b.com)'], 1, 25, 'http://b.com')

" --- Reference-style links ---
call s:check('full reference',
      \ ['See [label][ref] here', '', '[ref]: http://ref.example.com'], 1, 6,
      \ 'http://ref.example.com')
call s:check('full reference, cursor on ref token',
      \ ['See [label][ref] here', '', '[ref]: http://ref.example.com'], 1, 14,
      \ 'http://ref.example.com')
call s:check('collapsed reference [label][]',
      \ ['See [label][] here', '[label]: http://c.example.com'], 1, 6,
      \ 'http://c.example.com')
call s:check('shortcut reference [label]',
      \ ['See [label] here', '[label]: http://s.example.com'], 1, 6,
      \ 'http://s.example.com')
call s:check('reference is case-insensitive',
      \ ['See [Ref][] here', '[ref]: http://ci.example.com'], 1, 6,
      \ 'http://ci.example.com')
call s:check('reference definition with title',
      \ ['[label][ref]', '[ref]: http://t.example.com "title"'], 1, 2,
      \ 'http://t.example.com')
call s:check('reference definition with angle-bracket url',
      \ ['[label][ref]', '[ref]: <http://a.example.com/x y>'], 1, 2,
      \ 'http://a.example.com/x y')

" --- No link under cursor -> empty (lets open() fall back) ---
call s:check('plain text, no link',
      \ ['just some plain text'], 1, 5, '')
call s:check('cursor outside link on line that has one elsewhere',
      \ ['word [a](http://a.com)'], 1, 2, '')
call s:check('shortcut ref with no matching definition',
      \ ['See [label] here'], 1, 6, '')

" --- Report ---
call add(s:out, '')
if s:failures > 0
  call add(s:out, s:failures . ' of ' . s:count . ' FAILED')
else
  call add(s:out, 'all ' . s:count . ' tests passed')
endif
call writefile(s:out, '/dev/stdout')

if s:failures > 0
  cquit!
else
  qall!
endif
