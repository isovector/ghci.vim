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

function! ghci#type(name)
    " BUG: long types will require multiple tmux lines
    call tmux#send(":type " . a:name . "\n")
    let type = tmux#read(1)
    echom type
    return type
endfunction

function! ghci#filltype()
    let data = ghci#getarounddef()
    if len(data) ==# 0
        return
    endif

    if getline(data[1]) =~ "::"
        let winview = winsaveview()
        execute data[1] . "d"
        let data[2] = join( split(data[2], "\n")[1:], "\n")
        call winrestview(winview)
        normal! gk
    endif

    call tmux#sendcode(data[2])
    call append(data[1] - 1, ghci#type(data[0]))
endfunction

function! ghci#reloadfile()
    call tmux#send(":load " . expand("%:p") . "\n")
endfunction


function! ghci#getarounddef()
    let winview = winsaveview()
    let saveSearch = @/

    " Get first TLD above us
    while 1
        let line = getline(".")

        " Exit early if we hit a data keyword -- nothing to find
        if line =~ "\\v^(data|import|module|newtype|type)"
            echoerr "Not inside a definition"
            call winrestview(winview)
            return []
        endif

        if line =~ "\\v^([^ \t:\\=\\|]+)((\\s+[()a-zA-Z0-9]+)*\\s*(::|\\=|\\|))="
            silent normal! 0*
            break
        elseif line(".") ==# 1
            echoerr "Not inside a definition"
            call winrestview(winview)
            return []
        endif
        normal! k
    endwhile

    " Get the identifier we found from the search register
    let name = strpart(@/, 2, len(@/) - 4)
    let @/ = "^" . @/

    " Find the first occurance, but dont change jump list
    call setpos(".", [ 0, 1, 0, 0 ])
    silent normal! n
    let firstLine = line(".")

    " Find the next TLD below us, keeping track of lines between
    let regex = "\\v(^<" . name . ">|^\\s|^$)"
    let lines = ""
    while 1
        let line = getline(".")

        if line =~ regex
            let lines = lines . line . "\n"
            if line(".") ==# line("$")
                break
            else
                normal! j
            endif
        else
            break
        endif
    endwhile

    " Reset view
    call winrestview(winview)
    let @/ = saveSearch

    return [name, firstLine, lines]
endfunction

