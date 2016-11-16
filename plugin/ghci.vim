nnoremap <silent> zs :set opfunc=ghci#sendmove<CR>g@
nnoremap <silent> zss :call ghci#sendline()<CR>
" nnoremap <silent> st :call ghci#type(expand("<cword>"))<CR>
nnoremap <silent> zt :call ghci#filltype()<CR>
nnoremap <silent> zk :call ghci#reloadfile()<CR>
nnoremap <silent> zl :call ghci#reloadbuffer()<CR>
nnoremap <silent> zr :call ghci#runtest()<CR>
nnoremap <silent> zR :call ghci#unsettest()<CR>
nnoremap <silent> zc :call tmux#send("<C-Q><C-C>")<CR>
nnoremap <silent> zm :call tmux#send("main<C-Q><CR>")<CR>

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

