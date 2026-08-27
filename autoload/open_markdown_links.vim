" autoload/open_markdown_links.vim
" Extract the URL of the markdown link under the cursor and open it.

" Open the markdown link under the cursor in the browser.
" Falls back to open-browser.vim's own under-cursor handling (bare URLs,
" smart-search) when the cursor is not on a markdown link.
function! open_markdown_links#open() abort
  " open-browser.vim sets g:loaded_openbrowser and exposes openbrowser#open().
  " Check both: the autoload function may not be sourced yet (lazy autoload),
  " but g:loaded_openbrowser is set as soon as the plugin is installed.
  if !exists('g:loaded_openbrowser') && !exists('*openbrowser#open')
    echohl ErrorMsg
    echomsg 'open-markdown-links: open-browser.vim is not installed or loaded.'
    echohl NONE
    return
  endif
  let l:url = open_markdown_links#extract(getline(1, '$'), line('.'), col('.'))
  if !empty(l:url)
    call openbrowser#open(l:url)
    return
  endif
  " No markdown link here: defer to open-browser's own cursor handling.
  if !empty(maparg('<Plug>(openbrowser-open)'))
    execute "normal \<Plug>(openbrowser-open)"
  else
    echohl WarningMsg
    echomsg 'open-markdown-links: no link under the cursor.'
    echohl NONE
  endif
endfunction

" Byte-indexed single-char access, so indices line up with Vim's col().
function! s:at(line, i) abort
  return strpart(a:line, a:i, 1)
endfunction

" True when the char at index i is preceded by an odd number of backslashes.
function! s:escaped(line, i) abort
  let l:k = a:i - 1
  let l:bs = 0
  while l:k >= 0 && s:at(a:line, l:k) ==# '\'
    let l:bs += 1
    let l:k -= 1
  endwhile
  return l:bs % 2 == 1
endfunction

" Drop backslashes that escape ASCII punctuation, per CommonMark.
function! s:unescape(s) abort
  return substitute(a:s, '\\\([[:punct:]]\)', '\1', 'g')
endfunction

" Normalize a reference label for case-insensitive matching.
function! s:normalize(s) abort
  return tolower(substitute(trim(a:s), '\s\+', ' ', 'g'))
endfunction

" Parse a bracketed label starting at index a:start (which points at '[').
" Returns [closing_bracket_index, label_text] or [-1, ''] if unterminated.
function! s:parse_label(line, start) abort
  let l:n = strlen(a:line)
  let l:depth = 0
  let l:i = a:start
  let l:esc = 0
  let l:text = ''
  while l:i < l:n
    let l:c = s:at(a:line, l:i)
    if l:esc
      let l:text .= l:c
      let l:esc = 0
      let l:i += 1
      continue
    endif
    if l:c ==# '\'
      let l:esc = 1
      let l:i += 1
      continue
    endif
    if l:c ==# '['
      let l:depth += 1
      if l:depth > 1
        let l:text .= l:c
      endif
      let l:i += 1
      continue
    endif
    if l:c ==# ']'
      let l:depth -= 1
      if l:depth == 0
        return [l:i, l:text]
      endif
      let l:text .= l:c
      let l:i += 1
      continue
    endif
    let l:text .= l:c
    let l:i += 1
  endwhile
  return [-1, '']
endfunction

" Parse an inline destination starting at index a:start (which points at '(').
" Returns [closing_paren_index, url] or [-1, ''] if unterminated.
function! s:parse_inline_dest(line, start) abort
  let l:n = strlen(a:line)
  let l:i = a:start + 1
  while l:i < l:n && s:at(a:line, l:i) =~# '\s'
    let l:i += 1
  endwhile
  let l:url = ''
  if l:i < l:n && s:at(a:line, l:i) ==# '<'
    " Angle-bracket destination: verbatim until an unescaped '>'.
    let l:i += 1
    let l:esc = 0
    while l:i < l:n
      let l:c = s:at(a:line, l:i)
      if l:esc
        let l:url .= l:c
        let l:esc = 0
        let l:i += 1
        continue
      endif
      if l:c ==# '\'
        let l:esc = 1
        let l:i += 1
        continue
      endif
      if l:c ==# '>'
        let l:i += 1
        break
      endif
      let l:url .= l:c
      let l:i += 1
    endwhile
  else
    " Plain destination: balanced parens, ends at depth-0 space or ')'.
    let l:depth = 0
    let l:esc = 0
    while l:i < l:n
      let l:c = s:at(a:line, l:i)
      if l:esc
        let l:url .= l:c
        let l:esc = 0
        let l:i += 1
        continue
      endif
      if l:c ==# '\'
        let l:esc = 1
        let l:i += 1
        continue
      endif
      if l:c =~# '\s' && l:depth == 0
        break
      endif
      if l:c ==# '('
        let l:depth += 1
        let l:url .= l:c
        let l:i += 1
        continue
      endif
      if l:c ==# ')'
        if l:depth == 0
          break
        endif
        let l:depth -= 1
        let l:url .= l:c
        let l:i += 1
        continue
      endif
      let l:url .= l:c
      let l:i += 1
    endwhile
  endif
  " Advance to the inline link's closing ')'.
  while l:i < l:n && s:at(a:line, l:i) !=# ')'
    let l:i += 1
  endwhile
  if l:i < l:n && s:at(a:line, l:i) ==# ')'
    return [l:i, l:url]
  endif
  return [-1, '']
endfunction

" Parse the destination portion of a reference definition line.
function! s:parse_definition_dest(rest) abort
  let l:s = trim(a:rest)
  if l:s ==# ''
    return ''
  endif
  if strpart(l:s, 0, 1) ==# '<'
    let l:end = stridx(l:s, '>')
    if l:end >= 0
      return s:unescape(strpart(l:s, 1, l:end - 1))
    endif
    return s:unescape(strpart(l:s, 1))
  endif
  return s:unescape(matchstr(l:s, '^\S\+'))
endfunction

" Find a reference definition [ref]: url anywhere in the buffer.
function! s:find_definition(lines, ref) abort
  let l:key = s:normalize(a:ref)
  if l:key ==# ''
    return ''
  endif
  for l:line in a:lines
    let l:m = matchlist(l:line, '^\s*\[\(.\{-}\)\]:\s*\(.*\)$')
    if empty(l:m)
      continue
    endif
    if s:normalize(l:m[1]) ==# l:key
      return s:parse_definition_dest(l:m[2])
    endif
  endfor
  return ''
endfunction

" Extract the URL of the markdown link at (a:lnum, a:col) within a:lines.
" a:col is a 1-based byte column (as returned by col('.')).
" Returns the URL, or '' when the cursor is not on a resolvable link.
function! open_markdown_links#extract(lines, lnum, col) abort
  if a:lnum < 1 || a:lnum > len(a:lines)
    return ''
  endif
  let l:line = a:lines[a:lnum - 1]
  let l:cur = a:col - 1
  let l:n = strlen(l:line)
  let l:i = 0
  while l:i < l:n
    if s:at(l:line, l:i) ==# '[' && !s:escaped(l:line, l:i)
      let [l:labend, l:label] = s:parse_label(l:line, l:i)
      if l:labend >= 0
        let l:after = l:labend + 1
        let l:nextc = l:after < l:n ? s:at(l:line, l:after) : ''
        if l:nextc ==# '('
          let [l:dend, l:url] = s:parse_inline_dest(l:line, l:after)
          if l:dend >= 0
            if l:cur >= l:i && l:cur <= l:dend
              return l:url
            endif
            let l:i = l:dend + 1
            continue
          endif
        elseif l:nextc ==# '['
          let [l:rend, l:ref] = s:parse_label(l:line, l:after)
          if l:rend >= 0
            let l:refkey = (l:ref ==# '') ? l:label : l:ref
            if l:cur >= l:i && l:cur <= l:rend
              return s:find_definition(a:lines, l:refkey)
            endif
            let l:i = l:rend + 1
            continue
          endif
        endif
        " Shortcut reference: [label] resolved against a definition.
        if l:cur >= l:i && l:cur <= l:labend
          return s:find_definition(a:lines, l:label)
        endif
        let l:i = l:labend + 1
        continue
      endif
    endif
    let l:i += 1
  endwhile
  return ''
endfunction
