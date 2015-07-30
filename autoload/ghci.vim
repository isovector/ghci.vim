function! ghci#sendmove(type, ...)
    let saveSel = &selection
    let &selection = "inclusive"
    let saveReg = @@

    if a:0  " Invoked from Visual mode, use '< and '> marks.
        silent exe "normal! `<" . a:type . "`>y"
    elseif a:type == 'line'
        silent exe "normal! '[V']y"
    elseif a:type == 'block'
        silent exe "normal! `[\<C-V>`]y"
    else
        silent exe "normal! `[v`]y"
    endif

    echom a:type

    let @@ = @@ . "\n"

    if a:type == "char"
        call tmux#send(@@)
    else
        call tmux#sendcode(@@)
    endif

    let &selection = saveSel
    let @@ = saveReg
endfunction

function! ghci#type()
    let word = expand("<cword>")
    call tmux#send(":type " . word . "\n")
endfunction

function! ghci#filltype()
    call ghci#type()
    execute "normal! \"=tmux#read(1)\<CR>Pj"
endfunction


