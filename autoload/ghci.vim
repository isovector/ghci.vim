" TODO:
"   - autocomplete
"   - refactor into where?
"   - INDENTING


sign define ghcitest text=HS

let s:nextSign = 65535
let s:funcTest = { }
let s:tmpFile = tempname() . ".hs"
let s:curExts = [ ]
let s:curFile = ""

function! s:strip(input_string)
    return substitute(a:input_string, '^\s*\(.\{-}\)\s*$', '\1', '')
endfunction

function! s:maps(l, fn)
    let new_list = deepcopy(a:l)
    call map(new_list, a:fn)
    return new_list
endfunction

function! s:map(fn, l)
    let new_list = deepcopy(a:l)
    call map(new_list, string(a:fn) . '(v:val)')
    return new_list
endfunction

function! s:filtered(fn, l)
    let new_list = deepcopy(a:l)
    call filter(new_list, string(a:fn) . '(v:val)')
    return new_list
endfunction

function! ghci#isextension(val)
  return strpart(a:val, 0, 3) == "!!!"
endfunction

function! ghci#extension(val)
  return matchstr(a:val, "\\v!!!\\zs([^ ]+)")
endfunction

function! ghci#getextensions()
    let lines = join(getline("^", 30), "")
    let tryMatch = s:filtered(function("ghci#isextension"), split(substitute(lines, "\\v\\{-#\\s*LANGUAGE\\s+([^#]+)#-\\}", "!!!\\1,", "g"), ","))
    if len(tryMatch) ==# 0
        return []
    endif

    return s:map(function("ghci#extension"), tryMatch)
endfunction

function! ghci#istypedef(lineno)
    let i = a:lineno
    let success = 0

    while i !=# line("$")
        let line = getline(i)
        if i !=# a:lineno && !(line =~ "\\v^\\s")
            if success
                return i - a:lineno
            else
                return 0
            end
        endif

        if line =~ "::"
            let success = 1
        endif

        let i += 1
    endwhile

    return 0
endfunction

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
        execute data[1] . "," . (data[1] + data[3] - 1) . "d"
        let data[2] = join( split(data[2], "\n")[1:], "\n")
        call winrestview(winview)
        normal! gk
    endif

    call tmux#sendcode(data[2])
    let type = ghci#capture(":type " . data[0] . "\n")
    call append(data[1] - 1, type)
endfunction

function! ghci#capture(what)
    call tmux#capture()
    call tmux#send(a:what) " no implicit newline so we can do autocomplete later
    return s:sanitize(tmux#getcapture())
endfunction

function! s:getnegation(val)
  if strpart(a:val, 0, 2) == "No"
    return strpart(a:val, 2)
  endif

  return "No" . a:val
endfunction

function! s:getflag(val)
  return "-X" . a:val
endfunction

function! ghci#reloadbuffer()
    let newExts = ghci#getextensions()

    let thisFile = expand("%:p")
    if s:curFile == thisFile
      call tmux#send(":r\n")
    else
      call tmux#send(":load " . thisFile . "\n")
    endif

    let s:curFile = thisFile

    if newExts !=# s:curExts
      if len(s:curExts) !=# 0
        let noOpts = join(s:map(function("s:getflag"), s:map(function("s:getnegation"), s:curExts)), " ")
        call tmux#send(":seti " . noOpts . "\n")
      endif

      let opts = join(s:map(function("s:getflag"), newExts), " ")
      call tmux#send(":seti " . opts . "\n")
    endif

    let s:curExts = newExts
endfunction

" TODO: probably deprecate this
function! ghci#reloadfile()
    call tmux#send(":load " . expand("%:p") . "\n")
endfunction

function! s:extractinfix()
    if strpart(@a, 0, 1) == '`'
        return expand("<cword>")
    else
        return "(" . @a . ")"
    endif
endfunction

function! s:getfunction()
    let winview = winsaveview()
    let saveReg = @a

    " So this doesn't work if you have spurious parens
    " or if you're using a pair or if you're an asshole
    let line = getline(".")
    if line =~ "\\v^\\([a-zA-Z(]"
        " Infix operator
        execute "normal! %wvhe\"ay\<ESC>"
        let name = s:extractinfix()
    elseif line =~ "\\v^\\("
        " Full operator
        execute "normal! v%\"ay\<ESC>"
        let name = @a
    else
        execute "normal! wvhe\"ay\<ESC>"
        if strpart(@a, 0, 1) =~ "[a-zA-Z0-9(:]" || @a ==# "=" || @a ==# "_"
            " Regular function
            normal! lbb
            let name = expand("<cword>")
        else
            let name = s:extractinfix()
        endif
    end

    call winrestview(winview)
    let @a = saveReg
    return name
endfunction

function! s:isline(which)
    return line(".") ==# (a:which =~ "\\v[0-9]+" ? a:which : line(a:which))
endfunction

function! ghci#getarounddef()
    let winview = winsaveview()
    let name = ""

    while !s:isline("1")
        keepjumps normal! {j
        while !s:isline("1") && getline(".") =~ "\\v^\\s"
            keepjumps normal! k{j
        endwhile

        if getline(".") =~ "\\v^(data|import|module|newtype|type|}|])" || s:isline("1")
            break
        endif

        let myname = s:getfunction()
        if name ==# ""
            let name = myname
            let firstline = line(".")
        elseif name == myname
            let firstline = line(".")
        else
            break
        endif

        normal! k
    endwhile

    if name ==# ""
        call winrestview(winview)
        return []
    endif

    call winrestview(winview)
    normal! ^

    while !s:isline("$")
        normal j
        while getline(".") =~ "\\v(^\\s|^$)" && !s:isline("$")
            normal! j
        endwhile

        if s:getfunction() !=# name
            break
        end
    endwhile

    let lines = join(getline(firstline, line(".") - 1), "\n")

    call winrestview(winview)
    return [name, firstline, lines, ghci#istypedef(firstline)]
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
    let line = a:data[1] + a:data[3]

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
        if s:isline("$")
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

function! s:sanitize(ugly)
    let result = join(a:ugly, "\n")
    let result = substitute(result, "\x1B>", "\n", "g")
    let result = substitute(result, "\x1B.", "", "g")
    let lines = split(result, "\n")

    return lines[1:len(lines)-2]
endfunction

