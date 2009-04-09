"
" Copyright 2007-2009, All Rights Reserved.
" File:          gtagsman.vim
" Brief:         Manages the gtags server information for each buffer
" Author:        Edward Leap Fox <edyfox AT gmail DOT com>
" Last Modified: 2009-04-09 12:41:51
" Version:       0.12
" Thanks:        Google Inc. Gtags team
" GetLatestVimScripts: 1983 1 :AutoInstall: GtagsClient.vba.gz
"

let g:google_tags_locations = {}

function! s:GetProjectPath(filename)
    let oldname = a:filename
    let path = fnamemodify(oldname, ":h")
    let isok = filereadable(path . "/.gtags")
    while !isok && oldname != path
        let oldname = path
        let path = fnamemodify(oldname, ":h")
        let isok = filereadable(path . "/.gtags")
    endwhile
    if isok
        return path
    endif
    return ""
endfunction

function! s:ReadServerInfo(filename)
    let result = []
    for line in readfile(a:filename)
        let tokens = split(line, ",")
        if len(tokens) != 4
            continue
        endif
        let i = 0
        while i < 4
            let tokens[i] = substitute(tokens[i], '^ \+\| \+$', "", "g")
            let i = i + 1
        endwhile
        if tokens[0] != "c++"
            \ && tokens[0] != "java"
            \ && tokens[0] != "python"
            continue
        endif
        if tokens[1] != "definition"
            \ && tokens[1] != "callgraph"
            continue
        endif
        let tokens[3] = str2nr(tokens[3])
        if tokens[3] < 1 || tokens[3] > 65535
            continue
        endif
        call add(result, tokens)
    endfor
    return result
endfunction

function! s:Escape(str)
    return escape(a:str, '"\')
endfunction

function! s:BufLeave()
    if exists("b:google_tags_server_list")
        for item in b:google_tags_server_list
            exec "py gtags.connection_manager.remove_server("
                \ . "\"" . s:Escape(item[0]) . "\", "
                \ . "\"" . s:Escape(item[1]) . "\", "
                \ . "\"" . s:Escape(item[2]) . "\", "
                \ . s:Escape(item[3]) . ")"
        endfor
    endif
endfunction

function! s:BufEnter()
    call GtagInitialize()
    let projpath = s:GetProjectPath(expand("%:p"))
    exe 'set tags-=' . g:google_tags
    if !exists("b:google_tags_server_list")
        if projpath != ""
            let b:google_tags_server_list = s:ReadServerInfo(fnamemodify(
                \ projpath . "/.gtags", ":p"))
            exec "py google_tags_proj_path = \""
                \ . s:Escape(fnamemodify(projpath, ":p")) . "\""
        endif
    endif
    if exists("b:google_tags_server_list")
        for item in b:google_tags_server_list
            exec "py gtags.connection_manager.add_server("
                \ . "\"" . s:Escape(item[0]) . "\", "
                \ . "\"" . s:Escape(item[1]) . "\", "
                \ . "\"" . s:Escape(item[2]) . "\", "
                \ . s:Escape(item[3]) . ")"
        endfor
        if !has_key(g:google_tags_locations, projpath)
            let g:google_tags_locations[projpath] = tempname()
            call system('touch ' . g:google_tags_locations[projpath])
        endif
        let g:google_tags = g:google_tags_locations[projpath]
        exe 'set tags+=' . g:google_tags
    else
        if !has_key(g:google_tags_locations, "/")
            let g:google_tags_locations["/"] = g:google_tags
        endif
        let g:google_tags = g:google_tags_locations["/"]
        exe 'set tags+=' . g:google_tags
    endif
endfunction

augroup google_tags_manager
    au!
    au BufEnter * call <SID>BufEnter()
    au BufLeave * call <SID>BufLeave()
augroup END

function s:GetCurSelection()
    let oldreg = getreg('f')
    let oldregmode = getregtype('f')
    normal gv"fy
    let result = getreg('f')
    call setreg('f', oldreg, oldregmode)
    return result
endfunction

function! s:HookShortcut(shortcut)
    exec "nnoremap <silent> " . a:shortcut
        \ . " :call GtagWriteExactMatch(expand('<cword>'))<CR>" . a:shortcut
    exec "vnoremap <silent> " . a:shortcut
        \ . " :call GtagWriteExactMatch(<SID>GetCurSelection())<CR>"
        \ . a:shortcut
endfunction

call s:HookShortcut("<C-]>")
call s:HookShortcut("g<LeftMouse>")
call s:HookShortcut("<C-LeftMouse>")
call s:HookShortcut("g]")
call s:HookShortcut("g<C-]>")
call s:HookShortcut("<C-w>}")
call s:HookShortcut("<C-w>g}")
