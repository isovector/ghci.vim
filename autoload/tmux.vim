let s:last_selected_pane = ""
let s:target = ""
let s:retry_send = ""
let s:capture_file = tempname()

function! g:_TmuxPickPaneFromBuf()
    " Get current line under the cursor
    let line = getline(".")

    " Parse target pane from current line
    let pane_match = matchlist(line, '\(^[^ ]\+\)\: ')

    if len(pane_match) == 0
      echo "Please select a pane with enter or exit with 'q'"
      return
    endif

    let target_pane = pane_match[1]

    " Hide (and destroy) the scratch buffer
    hide

    let s:target = target_pane
    let s:last_selected_pane = target_pane

    if len(s:retry_send) !=# 0
        call tmux#send(s:retry_send)
        let s:retry_send = ""
    endif
endfunction

function! tmux#SelectPane()
    if len(s:target) !=# 0
        return
    endif

    " Create new buffer in a horizontal split
    belowright new

    " Get some basic syntax highlighting
    set filetype=sh

    " Set header for the menu buffer
    call setline(1, "# Enter: Select pane - Esc/q: Cancel")
    call setline(2, "")

    " Add last used pane as the first
    if len(s:last_selected_pane) != 0
      call setline(3, s:last_selected_pane . ": (last one used)")
    endif

    " List all tmux panes at the end
    normal! G

    " Put tmux panes in the buffer.
    if !exists("g:slimux_pane_format")
      let g:slimux_pane_format = '#{session_name}:#{window_index}.#{pane_index}: #{window_name}: #{pane_title} [#{pane_width}x#{pane_height}] #{?pane_active,(active),}'
    endif

    " We need the pane_id at the beginning of the line so we can
    " identify the selected target pane
    let l:format = '#{pane_id}: ' . g:slimux_pane_format
    let l:command = "read !tmux list-panes -F '" . escape(l:format, '#') . "'"

    " if g:slimux_select_from_current_window = 1, then list panes from current
    " window only.
    if !exists("g:slimux_select_from_current_window") || g:slimux_select_from_current_window != 1
      let l:command .= ' -a'
    endif

    " Must use cat here because tmux might fail here due to some libevent bug in linux.
    " Try 'tmux list-panes -a > panes.txt' to see if it is fixed
    execute l:command . ' | cat'

    " Resize the split to the number of lines in the buffer,
    " limit to 10 lines maximum.
    execute min([ 10, line('$') ]) . 'wincmd _'

    " Move cursor to first item
    call setpos(".", [0, 3, 0, 0])

    " bufhidden=wipe deletes the buffer when it is hidden
    setlocal bufhidden=wipe buftype=nofile
    setlocal nobuflisted nomodifiable noswapfile nowrap
    setlocal cursorline nocursorcolumn

    " Hide buffer on q and <ESC>
    nnoremap <buffer> <silent> q :hide<CR>
    nnoremap <buffer> <silent> <ESC> :hide<CR>

    " Use enter key to pick tmux pane
    nnoremap <buffer> <silent> <Enter> :call g:_TmuxPickPaneFromBuf()<CR>

    " Use d key to display pane index hints
    nnoremap <buffer> <silent> d :call system("tmux display-panes")<CR>
endfunction

function! tmux#height()
    return tmux#do("display-message -pF '#{pane_height}'")
endfunction

function! tmux#do(cmd, ...)
    if a:0
        return system("tmux " . a:cmd . " -t " . s:target . " " . a:1)
    endif
    return system("tmux " . a:cmd . " -t " . s:target)
endfunction

function! s:fromBottom(n, height)
    let n = a:n

    if n ># 0
        return a:height - n - 1
    else
        return n * -1
    endif
endfunction

function! tmux#read(startLine, ...)
    let height = tmux#height()

    let startLine = a:startLine
    if a:0 ==# 0
        let endLine = startLine
    else
        let endLine = a:1
    endif

    let startLine = s:fromBottom(startLine, height)
    let endLine = s:fromBottom(endLine, height)
    let result = tmux#do("capture-pane -pS " . startLine . " -E " . endLine)

    return strpart(result, 0, len(result) - 1)
endfunction

function! tmux#capture()
    call writefile([], s:capture_file)
    call tmux#do("pipe-pane", "'cat >> " . s:capture_file . "'")
endfunction

function! tmux#getcapture()
    call tmux#do("pipe-pane")
    return readfile(s:capture_file)
endfunction

function! tmux#send(text)
    if s:target ==# ""
        let s:retry_send = a:text
        call tmux#SelectPane()
        return
    endif

    " The limit of text bytes tmux can send one time. 500 is a safe value.
    let s:sent_text_length_limit = 1000
    let text = a:text

    " If the text is too long, split the text into pieces and send them one by one
    while text != ""
        let local_text = strpart(text, 0, s:sent_text_length_limit)
        let text = strpart(text, s:sent_text_length_limit)
        let local_text = s:EscapeText(local_text)
        call system("tmux set-buffer -- " . local_text)
        call tmux#do("paste-buffer")
    endwhile
endfunction

function! tmux#sendcode(text)
    let text = haskell#escape(a:text)
    call tmux#send(text)
endfunction


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Helpers
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:EscapeText(text)
  return substitute(shellescape(a:text), "\\\\\\n", "\n", "g")
endfunction

function! s:ExecFileTypeFn(fn_name, args)
  let result = a:args[0]

  if exists("&filetype")
    let fullname = a:fn_name . &filetype
    if exists("*" . fullname)
      let result = call(fullname, a:args)
    end
  end

  return result
endfunction


" Thanks to http://vim.1045645.n5.nabble.com/Is-there-any-way-to-get-visual-selected-text-in-VIM-script-td1171241.html#a1171243
function! s:GetVisual() range
    let reg_save = getreg('"')
    let regtype_save = getregtype('"')
    let cb_save = &clipboard
    set clipboard&
    silent normal! ""gvy
    let selection = getreg('"')
    call setreg('"', reg_save, regtype_save)
    let &clipboard = cb_save
    return selection
endfunction

function! tmux#getbuffer()
    let l:winview = winsaveview()
    let reg_save = getreg('"')
    let regtype_save = getregtype('"')
    let cb_save = &clipboard
    set clipboard&
    silent normal! ggVGy
    let selection = getreg('"')
    call setreg('"', reg_save, regtype_save)
    let &clipboard = cb_save
    call winrestview(l:winview)
    return selection
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Code interface
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Code interface uses per buffer configuration

function! s:TmuxSendRange()  range abort
    if !exists("b:code_packet")
        let b:code_packet = { "target_pane": "", "type": "code" }
    endif
    let rv = getreg('"')
    let rt = getregtype('"')
    sil exe a:firstline . ',' . a:lastline . 'yank'
    call TmuxSendCode(@")
    call setreg('"',rv, rt)
endfunction


command! TmuxREPLSendLine call tmux#sendcode(getline(".") . "\n")
" command! -range=% -bar -nargs=* TmuxREPLSendSelection call TmuxSendCode(s:GetVisual())
" command! -range -bar -nargs=0 TmuxREPLSendLine <line1>,<line2>call s:TmuxSendRange()
" command! -range=% -bar -nargs=* TmuxREPLSendBuffer call TmuxSendCode(s:GetBuffer())
" command! -nargs=* TmuxRead call TmuxRead(<f-args>)

