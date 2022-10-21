nnoremap <buffer> <silent> zs :set opfunc=ghci#sendmove<CR>g@
nnoremap <buffer> <silent> zss :call ghci#sendline()<CR>
nnoremap <buffer> <silent> zt :call ghci#filltype()<CR>
nnoremap <buffer> <silent> zL :call ghci#reloadfile()<CR>
nnoremap <buffer> <silent> zl :call ghci#reloadbuffer()<CR>
nnoremap <buffer> <silent> zc :call tmux#send("<C-Q><C-C>")<CR>
nnoremap <buffer> <silent> zm :call tmux#send("main<C-Q><CR>")<CR>
nnoremap <buffer> <silent> zn :call tmux#send(":r<C-Q><CR>main<C-Q><CR>")<CR>

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

