let g:submode_timeout = 0

call submode#enter_with('ghci', 'n', 's', 's', ':call tmux#SelectPane()<CR>')
call submode#leave_with('ghci', 'n', '', '<Esc>')
call submode#map('ghci', 'n', 's', 't', ':call ghci#type()<CR>')
call submode#map('ghci', 'n', 's', 'T', ':call ghci#filltype()<CR>')
call submode#map('ghci', 'n', 's', 's', ':SubmodeRestoreOptions<CR>:set opfunc=ghci#sendmove<CR>g@')



