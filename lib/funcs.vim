vim9script

def PopupCallbackGrep(id: number, idx: number)
  if idx != -1
    var selection = getbufline(winbufnr(id), idx)[0]
    var file = selection->matchstr('^\S\{-}\ze:')
    var line = selection->matchstr(':\zs\d*\ze:')
    exe $'edit {file}'
    cursor(str2nr(line), 1)
  endif
enddef

def PopupCallbackFileBuffer(id: number, idx: number)
  if idx != -1
    echo ""
    var selection = getbufline(winbufnr(id), idx)[0]
    # If the selection is a directory
    if selection[-1] == '/' || selection[-1] == "\\"
      exe $'cd {selection}'
      pwd
    else
      exe $'edit {selection}'
    endif
  endif
enddef

def PopupCallbackHistory(id: number, idx: number)
  if idx != -1
    var cmd = getbufline(winbufnr(id), idx)[0]
    exe cmd
  endif
enddef

def PopupCallbackDir(id: number, idx: number)
  if idx != -1
    var dir = getbufline(winbufnr(id), idx)[0]
    exe $'cd {dir}'
    pwd
  endif
enddef

def ShowPopup(title: string, results: list<string>, type: string)

  var PopupCallback: func
  if type == 'file' || type == 'buffer' || type == 'recent_files'
    PopupCallback = PopupCallbackFileBuffer
  elseif type == 'dir'
    PopupCallback = PopupCallbackDir
  elseif type == 'history'
    PopupCallback = PopupCallbackHistory
  elseif type == 'grep'
    PopupCallback = PopupCallbackGrep
  endif

  popup_menu(results, {
    title: title,
    line: &lines,
    col: &columns,
    posinvert: false,
    callback: PopupCallback,
    borderchars: ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
    border: [1, 1, 1, 1],
    maxheight: &lines / 2,
    minwidth: &columns / 2,
    maxwidth: &columns / 2,
  })
enddef

export def FindFileOrDir(type: string)
  # Guard
  if type == 'file' && getcwd() == expand('~')
    echoe "You are in your home directory. Too many results."
    return
  endif

  # Main
  var substring = input($"{getcwd()} - {type} to search ('enter' for all): ")
  redraw
  echo "If the search takes too long hit CTRL-C few times and try to
        \ narrow down your search."
  var hidden = substring[0] == '.' ? '' : '*'
  var results = getcompletion($'**/{hidden}{substring}', type, true)

  if empty(results)
    echo $"'{substring}' pattern not found!"
  else
    var title = $" Search results for {type}s '{substring}': "
    if empty(substring)
      title = $" Search results for {type}s in {getcwd()}: "
    endif

    if type == 'file'
      filter(results, 'v:val !~ "\/$"')
    endif
    ShowPopup(title, results, type)
  endif
enddef

export def Vimgrep()
  # Guard
  if getcwd() == expand('~')
    echoe "You are in your home directory. Too many results."
    return
  endif

  # Main
  var what = input($"{getcwd()} - What to find: ")
  if empty(what)
    return
  endif

  var where = input($"{getcwd()} - in which files: ")
  if empty(where)
    return
  endif

  var vimgrep_options = input($"{getcwd()} - vimgrep options (empty = 'gj'): ")
  if empty(vimgrep_options)
    vimgrep_options = 'gj'
  endif

  var cmd = $'vimgrep /{what}/{vimgrep_options} **/{where}'
  redraw
  echo cmd
  exe cmd
  copen
enddef

export def Grep()
  # Guard
  if getcwd() == expand('~')
    echoe "You are in your home directory. Too many results."
    return
  endif

  # Main
  var what = input($"{getcwd()} - What to find: ")
  if empty(what)
    return
  endif

  var where = input($"{getcwd()} - in which files: ")
  if empty(where)
    where = '*'
  endif

  var cmd = ''
  if has('win32')
    # TODO
    # cmd = $"powershell -c command 'findstr /n /s /r {what} {where}'"
    cmd = $"findstr /n /s /r {what} {where}"
  else
    # cmd = $'shopt -s globstar; grep -n -r {what} {where}'
    cmd = $'grep -n -r --include="{where}" "{what}" .'
  endif
  redraw
  echom cmd
  var results = systemlist(cmd)

  var title = $" Grep results for '{what}': "
  ShowPopup(title, results, 'grep')
enddef

export def Buffers()
  var results = getcompletion('', 'buffer', true)
  var title = " Buffers: "
  ShowPopup(title, results, 'buffer')
enddef

export def RecentFiles()
  var results =  copy(v:oldfiles)
    ->filter((_, val) => filereadable(expand(val)))
    # ENABLE IF YOU WANT RELATIVE PATH
    # ->map((_, val) => fnamemodify(val, ':.'))
  # var title = $" Recently opened files ({getcwd()}): "
  var title = $" Recently opened files: "
  ShowPopup(title, results, 'recent_files')
enddef

export def CmdHistory()
  var results = split(execute('history :'), '\n')
  for ii in range(0, len(results) - 1)
    results[ii] = substitute(results[ii], '\v^\>?\s*\d*\s*(\w*)', ':\1', 'g')
  endfor
  var title = " Commands history: "
  ShowPopup(title, reverse(results[1 : ]), 'history')
enddef

# export def Dir()
#   var results = getcompletion('', 'dir')
#   insert(results, '..', 0)
#   var title = $" {getcwd()}/ "
#   ShowPopup(title, results, 'dir')
# enddef
