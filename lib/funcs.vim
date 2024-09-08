vim9script

var popup_width = &columns / 2
var popup_height = &lines / 2

# --- NOT USED but useful
def GetFiletypeByFilename(fname: string): string
    # NOT USED
    # Pretend to load a buffer and detect its filetype manually
    # Used in UpdatePreviewAlternative()

    # just return &filetype if buffer was already loaded
    if bufloaded(fname)
        return getbufvar(fname, '&filetype')
    endif

    new
    try
        # the `file' command never reads file data from disk
        # (but may read path/directory contents)
        # however the detection will become less accurate
        # as some types cannot be recognized for empty files
        noautocmd silent! execute 'file' fnameescape(fname)
        filetype detect
        return &filetype
    finally
        bwipeout!
    endtry
    return ''
enddef
# ------------ END NOT USED -----------

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

# --- NOT USED, but it may be useful
def UpdatePreviewAlternative(main_id: number, preview_id: number, search_type: string)
  # NOT USED
  # Alternative way for setting the filetype in the preview window.
  # It works with GetFiletypeByFilename() and it is slower
  var idx = line('.', main_id)
  var highlighted_line = getbufline(winbufnr(main_id), idx)[0]
  var buf_lines = readfile(expand(highlighted_line), '', popup_height)

  # UBA SPERMA
  var buf_filetype = GetFiletypeByFilename(highlighted_line)

  # Clean the preview
  popup_settext(preview_id, repeat([""], popup_height))
  # populate the preview
  # TODO readfile gives me folded content
  popup_settext(preview_id, buf_lines)
  # Syntax highlight
  win_execute(preview_id, $'&filetype = "{buf_filetype}"')

  # Set preview ID title
  var preview_id_opts = popup_getoptions(preview_id)
  preview_id_opts.title = $' {highlighted_line} '
  popup_setoptions(preview_id, preview_id_opts)
enddef
# ------------ END NOT USED -----------

# Update preview content
def UpdatePreview(main_id: number, preview_id: number, search_type: string, search_pattern: string)
  var idx = line('.', main_id)

  var filename = search_type != 'grep'
    ? getbufline(winbufnr(main_id), idx)[0]
    : getbufline(winbufnr(main_id), idx)[0]->matchstr('^\S\{-}\ze:')

  var line_nr = search_type != 'grep'
    ? popup_height / 2
    : str2nr(getbufline(winbufnr(main_id), idx)[0]->matchstr(':\zs\d*\ze:'))

# UBA FIGA
  var firstline = max([1, line_nr - popup_height / 2])

  # TODO: use external programs to count the lines if needed
  # var file_length = has('win32') ? str2nr(system('ls')) : str2nr(system($'wc -l {filename}')->matchstr('\s*\zs\d*'))

  var file_content = readfile($'{filename}')
  var file_length = len(file_content)
  var lastline = min([file_length, line_nr + popup_height / 2])

  # Alternative using external programs instead or 'readfile()'
  # var buf_lines = has('win32')
  #   ? systemlist($'powershell -c "Get-Content {filename} | Select-Object -Skip ({firstline} - 1) -First ({lastline} - {firstline} + 1)"')
  #   : systemlist($'sed -n "{firstline},{lastline}p" {filename}')

  var buf_lines = file_content[firstline - 1 : lastline]

  # Add line numbers
  for ii in range(0, len(buf_lines) - 1)
    buf_lines[ii] = $'{firstline + ii}   {buf_lines[ii]}'
  endfor

  var buf_filetypedetect_cmd = '&filetype = ""'

  # Alternative method uses GetFiletypeByFilename()
  var buf_extension = $'{fnamemodify(filename, ":e")}'
  var found_filetypedetect = autocmd_get({group: 'filetypedetect'})->filter($'v:val.pattern =~ "*\\.{buf_extension}$"')
  if !empty(found_filetypedetect)
    buf_filetypedetect_cmd = found_filetypedetect[0].cmd
  endif

  # Clean the preview
  popup_settext(preview_id, repeat([""], popup_height))
  # populate the preview
  # TODO readfile gives me folded content
  popup_settext(preview_id, buf_lines)
  # Syntax highlight
  win_execute(preview_id, buf_filetypedetect_cmd)
  win_execute(preview_id, '&wrap = false')

  # Set preview ID title
  var preview_id_opts = popup_getoptions(preview_id)
  preview_id_opts.title = $' {filename} '
  popup_setoptions(preview_id, preview_id_opts)

  # Highlight search pattern
  if search_type == 'grep'
    win_execute(preview_id, $'exe "match Search \"{search_pattern}\""')
  endif
enddef

def PopupFilter(main_id: number, preview_id: number, key: string, search_type: string, search_pattern: string): bool
  # Handle shortcuts
  if index(['j', "\<down>", "\<c-n>"], key) != -1
    win_execute(main_id, 'norm j')
    UpdatePreview(main_id, preview_id, search_type, search_pattern)
    return true
  elseif index(['k', "\<Up>", "\<c-p>"], key) != -1
    win_execute(main_id, 'norm k')
    UpdatePreview(main_id, preview_id, search_type, search_pattern)
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
def ShowPopup(title: string, results: list<string>, search_type: string, search_pattern: string = '')

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
  var show_preview = index(['file', 'recent_files', 'buffer', 'grep'], search_type) != -1
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
    opts.filter = (id, key) => PopupFilter(id, preview_id, key, search_type, search_pattern)
    # If too many results, the scrollbar overlap the preview popup
    var scrollbar_contrib = len(results) > opts.minheight ? 1 : 0
    opts.col = popup_width - popup_width / 2 - 2 - scrollbar_contrib

    UpdatePreview(main_id, preview_id, search_type, search_pattern)
  endif

  # Callback switch for main popup
  var PopupCallback: func
  if index(['file', 'recent_files', 'buffer'], search_type) != -1
    PopupCallback = (id, idx) => PopupCallbackFileBuffer(id, preview_id, idx)
  elseif search_type == 'dir'
    PopupCallback = PopupCallbackDir
  elseif search_type == 'history'
    PopupCallback = (id, idx) => PopupCallbackHistory(id, preview_id, idx)
  elseif search_type == 'grep'
    PopupCallback = (id, idx) => PopupCallbackGrep(id, preview_id, idx)
  endif

  # Set callback for the main popup
  opts.callback = PopupCallback
  popup_setoptions(main_id, opts)
enddef

# API. The following functions are associated to commands in the plugin file.
export def FindFileOrDir(search_type: string)
  # Guard
  if search_type == 'file' && getcwd() == expand('~')
    echoe "You are in your home directory. Too many results."
    return
  endif

  # Main
  var substring = input($"{getcwd()} - {search_type} to search ('enter' for all): ")
  redraw
  echo "If the search takes too long hit CTRL-C few times and try to
        \ narrow down your search."
  var hidden = substring[0] == '.' ? '' : '*'
  var results = getcompletion($'**/{hidden}{substring}', search_type, true)

  if empty(results)
    echo $"'{substring}' pattern not found!"
  else
    var title = $" Search results for {search_type}s '{substring}': "
    if empty(substring)
      title = $" Search results for {search_type}s in {getcwd()}: "
    endif

    if search_type == 'file'
      filter(results, 'v:val !~ "\/$"')
    endif
    ShowPopup(title, results, search_type)
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
  ShowPopup(title, results, 'grep', what)
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

# UBA STOCAZZO

export def CmdHistory()
  var results = split(execute('history :'), '\n')
  for ii in range(0, len(results) - 1)
    results[ii] = substitute(results[ii], '\v^\>?\s*\d*\s*(\w*)', ':\1', 'g')
  endfor
  var title = " Commands history: "
  ShowPopup(title, reverse(results[1 : ]), 'history')
enddef
