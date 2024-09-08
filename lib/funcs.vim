vim9script

var popup_width = &columns / 2
var popup_height = &lines / 2
var ext2ft = {}

# ----- Callback functions
def PopupCallbackGrep(id: number, preview_id: number, idx: number)
  if idx != -1
    if preview_id != -1
      popup_close(preview_id)
    endif

    var selection = getbufline(winbufnr(id), idx)[0]
    # grep return format is '/path/to/file.xyz:76: ...'
    # You must extract the filename and the line number
    var file = selection->matchstr('^\S\{-}\ze:')
    var line = selection->matchstr(':\zs\d*\ze:')
    exe $'edit {file}'
    cursor(str2nr(line), 1)
  endif
enddef

def PopupCallbackFileBuffer(id: number, preview_id: number, idx: number)
  if idx != -1
    if preview_id != -1
      popup_close(preview_id)
    endif
    echo ""
    var selection = getbufline(winbufnr(id), idx)[0]
    exe $'edit {selection}'
  endif
enddef

def PopupCallbackHistory(id: number, preview_id: number, idx: number)
  if idx != -1
    if preview_id != -1
      popup_close(preview_id)
    endif
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

# Filter functions
# TODO: differentiate with Grep
# TODO: add colorscheme
def UpdatePreview(main_id: number, preview_id: number, type: string)
  var idx = line('.', main_id)
  var highlighted_line = getbufline(winbufnr(main_id), idx)[0]
  # TODO: check
  # if !filereadable(highlighted_line) && highlighted_line !~ "I AM THE PREVIEW! MWAHAHAHA!"
  #   echo "The picked line is not a filename (most likely is a grep result)"
  # endif

  # Set preview ID title
  var preview_id_opts = popup_getoptions(preview_id)
  preview_id_opts.title = $' {highlighted_line} '
  popup_setoptions(preview_id, preview_id_opts)

  # Get filetype for syntax highlighting
  var buf_lines = readfile(expand(highlighted_line), '', popup_height)
  var buf_extension = $'{fnamemodify(highlighted_line, ":e")}'
  var found_filetypedetect = autocmd_get({group: 'filetypedetect'})->filter($'v:val.pattern =~ "\\.{buf_extension}$"')
  var buf_filetypedetect_cmd = '&filetype = ""'
  if !empty(found_filetypedetect)
    buf_filetypedetect_cmd = found_filetypedetect[0].cmd
  endif

  # Update the popup
  popup_settext(preview_id, repeat([""], popup_height))
  popup_settext(preview_id, buf_lines)
  # TODO readfile gives me folded content
  win_execute(preview_id, buf_filetypedetect_cmd)
enddef

def PopupFilter(main_id: number, preview_id: number, key: string, type: string, opts: dict<any>): bool
  # Handle shortcuts
  if index(['j', "\<down>", "\<c-n>"], key) != -1
    win_execute(main_id, 'norm j')
    UpdatePreview(main_id, preview_id, type)
    return true
  elseif index(['k', "\<Up>", "\<c-p>"], key) != -1
    win_execute(main_id, 'norm k')
    UpdatePreview(main_id, preview_id, type)
    return true
  elseif key == "\<esc>"
    popup_clear()
    return true
  else
    return popup_filter_menu(main_id, key)
  endif
enddef
#
# MAIN
def ShowPopup(title: string, results: list<string>, type: string)

  # Standard options
  var opts = {
    title: title,
    line: &lines,
    col: &columns,
    posinvert: false,
    borderchars: ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
    border: [1, 1, 1, 1],
    maxheight: popup_height,
    minwidth: popup_width,
    maxwidth: popup_width,
  }

  var main_id = popup_menu(results, opts)

  # Preview handling
  var preview_id = -1
  var show_preview = type == 'file' || type == 'buffer' || type == 'recent_files'
  # show_preview = false
  if show_preview
    # Common opts update
    popup_width = &columns / 3
    opts.pos = 'topleft'
    opts.line = popup_height - popup_height / 2
    opts.minwidth = popup_width
    opts.maxwidth = popup_width
    opts.minheight = &lines / 2
    opts.maxheight = &lines / 2

    # Opts for preview_id
    # TODO: with recent files is not very nice.
    opts.col = popup_width + popup_width / 2 + 2
    preview_id = popup_create("I AM THE PREVIEW! MWAHAHAHA!", opts)

    # Options for main_id
    opts.filter = (id, key) => PopupFilter(id, preview_id, key, type, opts)
    opts.col = popup_width - popup_width / 2 - 2

    UpdatePreview(main_id, preview_id, type)
  endif

  # Callback switch for main popup
  var PopupCallback: func
  if type == 'file' || type == 'buffer' || type == 'recent_files'
    PopupCallback = (id, idx) => PopupCallbackFileBuffer(id, preview_id, idx)
  elseif type == 'dir'
    PopupCallback = PopupCallbackDir
  elseif type == 'history'
    PopupCallback = (id, idx) => PopupCallbackHistory(id, preview_id, idx)
  elseif type == 'grep'
    PopupCallback = (id, idx) => PopupCallbackGrep(id, preview_id, idx)
  endif

  # Set callback for the main popup
  opts.callback = PopupCallback
  popup_setoptions(main_id, opts)
enddef

# API. The following functions are associated to commands in the plugin file.
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
    where = '*'
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
