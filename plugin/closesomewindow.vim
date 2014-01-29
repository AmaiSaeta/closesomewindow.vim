scriptencoding utf-8

command! -nargs=1 -bang CloseSomeWindow
\	call <SID>call(<f-args>, '<bang>' == '!')

function! s:call(args, bang)
	let [filterType, filterStr] = s:parseArguments(a:args)
	call s:closeSomeWindow(filterStr, filterType, a:bang)
endfunction

function! s:parseArguments(args)
	let parts = matchlist(a:args, '\v^%(-(s%(cript)?|f%(unction)?)\s+)?(.+)$')
	return [parts[1][0], parts[2]]
endfunction

function! s:closeSomeWindow(filter, filterType, needDialog) abort
" Close some window without focus to the target window.
" If target windows exist more than one, This function ask you.
" {{{
" @param	filter
" 	Close a window that fill this condition. If not exists filling this
" 	condition, this function does nothing.
" 	This argument retrieves a string or a funcref.
" 	If it's a string: like filter()'s 2nd argument. v:val has the window
" 	number.
" 	If it's a funcref: be used filtering. This funcref retrieves argument
" 	is windows numbers list, and must returns windows numbers list that
" 	filtering result.
" }}}

	let winnrs = range(1, tabpagewinnr(tabpagenr(), '$'))

	if(a:filterType ==# 'f')
		let winnrs = eval(a:filter . '(winnrs)')
	else
		call filter(winnrs, a:filter)
	endif

	let winnrsLen = len(winnrs)
	if winnrsLen == 0
		return
	elseif (winnrsLen == 1) || a:needDialog
		call s:do(winnrs[0])
	else	" greater than
		let chooseWinnr = s:dialog(winnrs)

		if chooseWinnr < 0 | return | endif " canseled

		call s:do(chooseWinnr)
	endif
endfunction

function! s:ls(all)
" Return the STRUCTURED all buffer informations that is similar :ls.
" @param[in]	all	Include "unlisted" buffer informations.
" @return
" 	Buffer informations. It's a List that contains Dictionary of a buffer
" 	informatin. Its Dictionary is composed these members:
" 		bufnr:      Buffer number.
" 		unlisted:   If 1, this buffer is "unlisted", otherwise 0.
"		focus:      "%" means in current window. "#" means alternate buffer.
"		active:     "a" means active buffer. "h" means hidden buffer.
"		modifiable: If 1, this buffer with 'modifiable' off, otherwise 0.
"		readonly:   If 1, a readonly buffer.
"		modified:   If 1, a modified buffer.
"		readerror:  If 1, a buffer with read errors.
"		bufname:    Buffer name. it's like bufname(), but has few different.
"		line:       Cursor position.

	" Get :ls result
	redir => cRes0
		execute 'silent ls' . (a:all ? '!' : '')
	redir END
	let cRes = split(cRes0, "\n")
	unlet cRes0

	" Parse
	let sRes = []
	for i in cRes
		" Parse a line of :ls.
		let items = map(
		\	matchlist(i, '\v^\s*(\d+)(.)(.)(.)(.)(.)\s+"([^"]+)".{-}(\d+).*$'),
		\	'v:val == " " ? "" : v:val')
		call add(sRes, {
		\	'bufnr'     : items[1],
		\	'unlisted'  : len(items[2]),
		\	'focus'     : items[3],
		\	'active'    : items[4],
		\	'modifiable': items[5] != '-',
		\	'readonly'  : items[5] == '=',
		\	'modified'  : items[6] == '+',
		\	'readerror' : items[6] == 'x',
		\	'bufname'   : items[7],
		\	'line'      : items[8]
		\ })
	endfor

	return sRes
endfunction

function! s:generateWindowList(winnrs)
" Return a dictionary that are displayed window; The key is the winnr,
" the value is the window's name.
" @param[in]	winnrs

	" Sometimes, bufname() returns  a empty string, or a incommodious
	" string. For example, on Quickfix window, it is a empty string.
	" Furthermore, it depends the setting of PWD.
	" :ls displayed is better than bufname() result. Therefore,
	" this function uses :ls output.
	let lsRes = s:ls(1)

	" Create winnr-bufname dictionary
	let winNames = {}
	for i in range(1, tabpagewinnr(tabpagenr(), '$'))
		if index(a:winnrs, i) == -1 | continue | endif

		let winNames[i] = filter(deepcopy(lsRes),
		\	'v:val["bufnr"] == winbufnr(i)')[0]['bufname']
	endfor

	return winNames
endfunction

function! s:dialog(winnrs)
	" When Unite.vim dosen't exists.
	"  [TODO]  When Unite.vim exists.
	let winList = s:generateWindowList(a:winnrs)
	let bufNameListStr
	\	= ["Select window number that you want delete;"]
	\		+ values(map(winList, 'v:key . " : " . v:val'))
	let res = inputlist(bufNameListStr)

	return (index(a:winnrs, res) == -1) ? -1 : res
endfunction

function! s:do(winnr) abort
	let currentWinnr = winnr()
	execute string(a:winnr) . "wincmd w"
	close
endfunction
