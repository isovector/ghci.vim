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

    let @@ = @@ . "\n"

    if a:type == "char"
        call tmux#send(@@)
    else
        call tmux#sendcode(@@)
    endif

    let &selection = saveSel
    let @@ = saveReg
endfunction

function! ghci#sendline()
    call tmux#sendcode(getline("."))
endfunction

function! ghci#type()
    let word = expand("<cword>")
    call tmux#send(":type " . word . "\n")
    let type = tmux#read(1)
    echom type
    return type
endfunction

function! ghci#filltype()
    let saveReg = @a
    let @a = ghci#type()
    normal! "aPj
    let @a = saveReg
endfunction


function! ghci#reloadfile()
    call tmux#send(":load " . expand("%:p") . "\n")
endfunction
