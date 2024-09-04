vim9script

def FindPopupCallbackFileBuffer(id: number, idx: number)
  if idx != -1
    echo ""
    var buf = getbufline(winbufnr(id), idx)[0]
    execute($'edit {buf}')
  endif
enddef

def FindPopupCallbackHistory(id: number, idx: number)
  if idx != -1
    var cmd = getbufline(winbufnr(id), idx)[0]
    execute(cmd, "")
  endif
enddef

def FindPopupCallbackDir(id: number, idx: number)
  if idx != -1
    var dir = getbufline(winbufnr(id), idx)[0]
    execute($'cd {dir}')
    pwd
    FindDir()
  endif
enddef

def ShowPopup(title: string, results: list<string>, type: string)

  var FindPopupCallback: func
  if type == 'file' || type == 'buffer' || type == 'recent_files'
    FindPopupCallback = FindPopupCallbackFileBuffer
  elseif type == 'dir'
    FindPopupCallback = FindPopupCallbackDir
  elseif type == 'history'
    FindPopupCallback = FindPopupCallbackHistory
  endif

  popup_menu(results, {
    title: title,
    line: &lines,
    col: &columns,
    posinvert: false,
    callback: FindPopupCallback,
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

def LazyFindFile()
  if getcwd() == expand('~')
    echoe "You are in your home directory. Too many results."
  else
    var substring = input("File to search: ")
    var results = getcompletion($'**/*{substring}', 'file')
    redraw

    if empty(results)
      echo $"\n'{substring}' pattern not found!"
    else
      echo "If the search takes too long hit CTRL-C few times and try to
            \ narrow down your search."
      var title = $" Search results for '{substring}': "
      ShowPopup(title, results, 'file')
    endif
  endif
enddef

export def FindBuffer()
  var results = getcompletion('', 'buffer')
  var title = " Buffers: "
  ShowPopup(title, results, 'buffer')
enddef

export def FindRecentFiles()
  var results =  copy(v:oldfiles)->filter((_, val) => filereadable(expand(val)))
  var title = " Recently opened files: "
  ShowPopup(title, results, 'recent_files')
enddef

export def FindCmdHistory()
  var results = split(execute('history :'), '\n')
  for ii in range(0, len(results) - 1)
    results[ii] = substitute(results[ii], '\v^\>?\s*\d*\s*(\w*)', ':\1', 'g')
  endfor
  var title = " Commands history: "
  ShowPopup(title, reverse(results[1 : ]), 'history')
enddef

export def FindDir()
  var results = getcompletion('', 'dir')
  insert(results, '..', 0)
  var title = $" {getcwd()}/ "
  ShowPopup(title, results, 'dir')
enddef
