command! GhciInit call tmux#SelectPane()

nnoremap <silent> ss :set opfunc=ghci#sendmove<CR>g@
nnoremap <silent> sss :call ghci#sendline()<CR>
nnoremap <silent> st :call ghci#type()<CR>
nnoremap <silent> sT :call ghci#filltype()<CR>
nnoremap <silent> sL :call ghci#reloadfile()<CR>


