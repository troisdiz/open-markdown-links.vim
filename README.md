# open-markdown-links.vim

Open the URL of the markdown link under your cursor in the browser.

With the cursor anywhere on a markdown link — the label or the URL — this
plugin extracts the link's destination and opens it, instead of grabbing
whatever bare word sits under the cursor. The browser launch itself is
delegated to [open-browser.vim](https://github.com/tyru/open-browser.vim).

```
[Vim](https://en.wikipedia.org/wiki/Vim_(text_editor))
 ^ cursor anywhere here opens the full URL, trailing paren and all
```

## Requirements

- Vim 8.0.1630+
- [tyru/open-browser.vim](https://github.com/tyru/open-browser.vim)

## Installation

With [vim-plug](https://github.com/junegunn/vim-plug):

```vim
Plug 'tyru/open-browser.vim'
Plug 'open-markdown-links.vim'   " or your fork's user/repo
```

Or with Vim 8 native packages:

```sh
git clone https://github.com/tyru/open-browser.vim \
  ~/.vim/pack/plugins/start/open-browser.vim
git clone <this-repo> \
  ~/.vim/pack/plugins/start/open-markdown-links.vim
```

## Usage

Put the cursor on a markdown link and run:

```vim
:OpenMarkdownLink
```

### Suggested mapping

No key is mapped by default. Bind the provided `<Plug>` mapping in your vimrc:

```vim
nmap gx <Plug>(open-markdown-link)
```

Or scope it to markdown buffers:

```vim
autocmd FileType markdown nmap <buffer> gx <Plug>(open-markdown-link)
```

## What it handles

- **Inline links** `[label](url)` — cursor on the label or the URL.
- **Titles** are stripped: `[x](url "title")` → `url`.
- **Balanced parentheses** in the URL: `…/Vim_(text_editor)`.
- **Angle-bracket destinations**: `[x](<url with spaces>)`.
- **Square brackets** in the URL: IPv6 `http://[::1]:8080/`, query strings.
- **Escaped delimiters** `\(` `\)` `\[` `\]` inside the URL.
- **Reference links** — full `[label][ref]`, collapsed `[label][]`, and
  shortcut `[label]` — resolved against a `[ref]: url` definition anywhere
  in the buffer (case-insensitive).
- **Fallback**: when the cursor is not on a markdown link, it defers to
  `<Plug>(openbrowser-open)`, so bare URLs and open-browser's smart-search
  still work.

## Tests

Headless test suites (require `vim`):

```sh
./test/run.sh
```

`test/test_extract.vim` covers the pure URL-extraction logic;
`test/test_open.vim` covers the command, the `<Plug>` mapping, and the
fallback, using a test double for open-browser.vim.
