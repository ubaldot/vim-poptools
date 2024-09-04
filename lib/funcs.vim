vim9script

def PopupCallbackFileBuffer(id: number, idx: number)
  if idx != -1
    echo ""
    var buf = getbufline(winbufnr(id), idx)[0]
    execute($'edit {buf}')
  endif
enddef

def PopupCallbackHistory(id: number, idx: number)
  if idx != -1
    var cmd = getbufline(winbufnr(id), idx)[0]
    execute(cmd, "")
  endif
enddef

def PopupCallbackDir(id: number, idx: number)
  if idx != -1
    var dir = getbufline(winbufnr(id), idx)[0]
    execute($'cd {dir}')
    pwd
    # if dir == '..'
    #   FindFileOrDir('dir')
    # endif
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
  endif

  popup_menu(results, {
    title: title,
    line: &lines,
    col: &columns,
    posinvert: false,
    callback: PopupCallback,
    filter: (id, key) => {
      # Handle shortcuts
      if key == '<\esc>'
        popup_close(id, -1)
      else
        return popup_filter_menu(id, key)
      endif
      return true
    },
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
  var substring = input($"{type} to search ('esc' or 'enter' for all the {type}s in the current dir): ")
  redraw
  echo "If the search takes too long hit CTRL-C few times and try to
        \ narrow down your search."
  var results = getcompletion($'**/*{substring}', type)
  # if type == 'dir'
  #   insert(results, '..', 0)
  # endif

  if empty(results)
    echo $"\n'{substring}' pattern not found!"
  else
    var title = $" Search results for {type}s '{substring}': "
    if empty(substring)
      title = $" Search results for {type}s in the current dir: "
    endif
    ShowPopup(title, results, type)
  endif
enddef

export def Buffers()
  var results = getcompletion('', 'buffer')
  var title = " Buffers: "
  ShowPopup(title, results, 'buffer')
enddef

export def RecentFiles()
  var results =  copy(v:oldfiles)->filter((_, val) => filereadable(expand(val)))
  var title = " Recently opened files: "
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
