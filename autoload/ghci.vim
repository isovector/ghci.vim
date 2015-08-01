sign define ghcitest text=HS

let s:nextSign = 65535
let s:funcTest = { }
let s:tmpFile = tempname() . ".hs"

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

    if data[3]
        let winview = winsaveview()
        execute data[1] . "d"
        let data[2] = join( split(data[2], "\n")[1:], "\n")
        call winrestview(winview)
        normal! gk
    endif

    call tmux#sendcode(data[2])
    call append(data[1] - 1, ghci#type(data[0]))
endfunction

function! ghci#reloadbuffer()
    exe "w " . s:tmpfile
    call tmux#send(":load " . s:tmpfile . "\n")
endfunction

" TODO: probably deprecate this
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

    return [name, firstLine, lines, getline(firstLine) =~ "::"]
endfunction

function! ghci#defnI()
    return s:defnObj(0)
endfunction

function! ghci#defnA()
    return s:defnObj(1)
endfunction

function! s:defnObj(around)
    let data = ghci#getarounddef()
    if len(data) ==# 0
        return 0
    end

    let lines = reverse(split(data[2], "\n"))
    let empty = 0

    if a:around == 0
        let i = 0
        while lines[i] =~ "\\v^\\s*$"
            let empty = empty + 1
            let i = i + 1
        endwhile
    endif

    let lineCount = len(lines) - empty - 1
    let endLine = data[1] + lineCount
    return ['v', [0, data[1], 0, 0], [0, endLine, len(getline(endLine)), 0]]
endfunction

function! ghci#ignoremodule(text)
    let lines = split(a:text, "\n")

    if lines[0] =~ "^module"
        let i = 1
        while lines[i] =~ "^\\v\\s+"
            let i = i + 1
        endwhile

        return join(lines[(i):], "\n")
    endif

    return a:text
endfunction

function! ghci#unsettest(...)
    if !a:0
        let data = ghci#getarounddef()
        let name = data[0]
    else
        let name = a:1
    end

    if !has_key(s:funcTest, name)
        return
    end

    let func = s:funcTest[name]
    let buf = bufnr("%")
    execute "sign unplace " . func.sign . " buffer=" . buf
    unlet s:funcTest[name]
endfunction

function! ghci#settest(data)
    call inputsave()
    let test = input('Test to run for ' . a:data[0] . ': ')
    call inputrestore()

    if !len(test)
        return 0
    end

    let s:funcTest[a:data[0]] = { 'sign': s:nextSign, 'test': test }
    let line = a:data[1] + (a:data[3] ? 1 : 0)

    let buf = bufnr("%")
    execute "sign place " . s:nextSign . " name=ghcitest line=" . line . " buffer=" . buf
    let s:nextSign = s:nextSign + 1

    return 1
endfunction

function! ghci#runtest()
    let data = ghci#getarounddef()
    if !has_key(s:funcTest, data[0])
        if !ghci#settest(data)
            return
        end
    endif

    call tmux#sendcode(data[2])
    call tmux#send(s:funcTest[data[0]].test . "\n")
endfunction

" TODO: not sure we need this either
function! ghci#loadimports()
    let winview = winsaveview()
    let inImport = 0
    let curImport = ""

    normal! gg
    while 1
        if line(".") ==# line("$")
            break
        endif

        let line = getline(".")
        if inImport
            if line =~ "^\\v\\s+"
                let curImport = curImport . line
            else
                let inImport = 0
                call tmux#sendcode(curImport)
                let curImport = ""
            end
        endif

        if line =~ "\\v^import\\s"
            let curImport = line
            let inImport = 1
        endif

        normal! j
    endwhile

    call winrestview(winview)
endfunction

function! ghci#parsetmux(ugly)
    let result = join(a:ugly, "\n")
    let result = substitute(result, "\x1B>", "\n", "g")
    let result = substitute(result, "\x1B.", "", "g")
    let lines = split(result, "\n")

    return lines[1:len(lines)-2]
endfunction

