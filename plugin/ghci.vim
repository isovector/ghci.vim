nnoremap <silent> ss :set opfunc=ghci#sendmove<CR>g@
nnoremap <silent> sss :call ghci#sendline()<CR>
nnoremap <silent> st :call ghci#type(expand("<cword>"))<CR>
nnoremap <silent> sT :call ghci#filltype()<CR>
nnoremap <silent> sL :call ghci#reloadbuffer()<CR>
nnoremap <silent> sr :call ghci#runtest()<CR>
nnoremap <silent> sR :call ghci#unsettest()<CR>

" We can do move-n-function
call textobj#user#plugin('ghcivim', {
\   'defn': {
\     'select-a-function': 'ghci#defnA',
\     'select-a': 'ab',
\     'select-i-function': 'ghci#defnI',
\     'select-i': 'ib',
\   },
\ })

" TODO: set a vim filetype for this
" nnoremap ;' :source %<CR>

