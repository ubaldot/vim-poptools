vim9script

# TODO Exclude 'wildignore' paths in Grep (it uses an external program)
# TODO Study how can you make popup_width and popup_height them parametric
var popup_width = &columns / 2
var popup_height = &lines / 2

var last_results = []
var last_title = ''
var last_search_type = ''
var last_search_pattern = ''

def Echoerr(msg: string)
  echohl ErrorMsg | echom $"{msg}" | echohl None
enddef

# ----- Callback functions
def PopupCallbackGrep(id: number, preview_id: number, idx: number)
  if idx > 0
    if preview_id != -1
      popup_close(preview_id)
    endif

    var selection = getbufline(winbufnr(id), idx)[0]
    # grep return format is 'file.xyz:76: ...'
    # You must extract the filename and the line number.
    # However, the name is not full, and you must reconstruct. The easiest
    # way is to fetch it from the popup title
    #
    # OBS! You could use split(selection, ':') to separate filename from line
    # number, but what if a filename is 'foo:bar'?
    var file = selection->matchstr('^\S\{-}\ze:')
    var line = selection->matchstr(':\zs\d*\ze:')

    var path = split(popup_getoptions(id).title)[0]
    exe $'edit {path}/{file}'
    cursor(str2nr(line), 1)

  endif
enddef

def PopupCallbackFileBuffer(id: number, preview_id: number, idx: number)
  if idx > 0
    if preview_id != -1
      popup_close(preview_id)
    endif
    echo ""
    var selection = getbufline(winbufnr(id), idx)[0]
    exe $'edit {selection}'

  endif
enddef

def PopupCallbackHistory(id: number, preview_id: number, idx: number)
  if idx > 0
    if preview_id != -1
      popup_close(preview_id)
    endif
    var cmd = getbufline(winbufnr(id), idx)[0]
    exe cmd
  endif
enddef

def PopupCallbackDir(id: number, idx: number)
  if idx > 0
    var dir = getbufline(winbufnr(id), idx)[0]
    exe $'cd {dir}'
    pwd
  endif
enddef

def PopupCallbackColorscheme(id: number, idx: number)
  if idx > 0
    var scheme = getbufline(winbufnr(id), idx)[0]
    noa exe $'colorscheme {scheme}'
  endif
enddef

# ------- Filter functions
# You  may use external programs to count the lines if 'readfile()' is too
# slow, e.g.
# var file_length = has('win32') ? str2nr(system('...')) : str2nr(system($'wc
# -l {filename}')->matchstr('\s*\zs\d*'))
# var buf_lines = has('win32')
#   ? systemlist($'powershell -c "Get-Content {filename} | Select-Object -Skip
#   ({firstline} - 1) -First ({lastline} - {firstline} + 1)"')
#   : systemlist($'sed -n "{firstline},{lastline}p" {filename}')
#
# For the syntax highlight, you may use the 'GetFiletypeByFilename()' function
#
def UpdateFilePreview(main_id: number, preview_id: number, search_type: string, search_pattern: string)
  # Parse the highlighted line on the main popup
  var idx = line('.', main_id)

  # This "if" is needed because the filter is called on <cr> anyways
  if idx > 0
    var filename = search_type !=# 'grep'
      ? getbufline(winbufnr(main_id), idx)[0]
      : getbufline(winbufnr(main_id), idx)[0]->matchstr('^\S\{-}\ze:')

    var line_nr = search_type !=# 'grep'
      ? popup_height / 2
      : str2nr(getbufline(winbufnr(main_id), idx)[0]->matchstr(':\zs\d*\ze:'))

    # We split the fullname so that we can show it nicely in the popup.
    # However, when showing the preview or during the callback, it is safer to
    # have the fullname. The path is in the popup title.
    # In case of Buffers or Recent files, that is not needed
    if index(['file', 'file_in_path', 'grep'], search_type) != -1
      var path = split(popup_getoptions(main_id).title)[0]
      filename = $'{path}/{filename}'
    endif

    var file_content = []
    if bufexists(filename)
      file_content = getbufline(filename, 1, '$')
    # TODO: check if you can remove the expand()
    elseif filereadable($'{expand(filename)}')
      file_content = readfile($'{expand(filename)}')
    else
      file_content = ["Can't preview the file!"]
    endif

    # Set options
    win_execute(preview_id, $'setlocal number')
    # win_execute(preview_id, '&wrap = false')

    # clean the preview
    popup_settext(preview_id, repeat([""], popup_height))
    # populate the preview
    setwinvar(preview_id, 'buf_lines', file_content)
    win_execute(preview_id, 'append(0, w:buf_lines)')
    # Unfold stuff
    win_execute(preview_id, 'norm! zR')

    # Highlight grep matches
    if !empty(search_pattern)
      win_execute(preview_id, $'normal! {line_nr}gg')
      win_execute(preview_id, $'setlocal cursorline')
      win_execute(preview_id, $'match Search /{search_pattern}/')
    endif

    # Syntax highlight if it creates problems, disable it. It is not
    # bulletproof
    if get(g:poptools_config, 'preview_syntax', true)
      # set 'synmaxcol' for avoiding crashing if some readable file has
      # embedded
      # figures. Figure generate lines with >80000 columns and the internal
      # engine to figure out the syntax will fail.
      var old_synmaxcol = &synmaxcol
      &synmaxcol = 300
      var buf_extension = $'{fnamemodify(filename, ":e")}'
      var found_filetypedetect_cmd = autocmd_get({group:
        'filetypedetect'})->filter($'v:val.pattern =~ "*\\.{buf_extension}$"')
      var set_filetype_cmd = empty(found_filetypedetect_cmd)
        ? '&filetype = ""'
        : found_filetypedetect_cmd[0].cmd
      win_execute(preview_id, set_filetype_cmd)
      &synmaxcol = old_synmaxcol
    endif

    # Set preview ID title
    var preview_id_opts = popup_getoptions(preview_id)
    preview_id_opts.title = $' {fnamemodify(filename, ':t')} '
    popup_setoptions(preview_id, preview_id_opts)
  endif

enddef

def ClosePopups(main_id: number, preview_id: number)
  if preview_id != -1
    popup_close(preview_id)
  endif
  # Remove the callback because popup_close() triggers the callback anyway.
  var opts = popup_getoptions(main_id)
  opts.callback = ''
  popup_setoptions(main_id, opts)
  popup_close(main_id)
enddef

def PopupFilter(main_id: number, preview_id: number, key: string, search_type: string, search_pattern: string): bool

  if index(['file', 'file_in_path', 'grep'], search_type) != -1
    # Save for last search
    last_results = getbufline(winbufnr(main_id), 1, '$')
    last_title = popup_getoptions(main_id).title
    last_search_type = search_type
    last_search_pattern = search_pattern
  endif

  # Handle shortcuts
  if key == "\<esc>"
    ClosePopups(main_id, preview_id)
    return true
  else
    popup_filter_menu(main_id, key)
    UpdateFilePreview(main_id, preview_id, search_type, search_pattern)
    return true
  endif
enddef

def ShowColorscheme(main_id: number, current_background: string)
  # Circular selection
  var idx = line('.', main_id) % (line('$', main_id) + 1)
  # I need this check because when user makes a selection with <cr> this
  # function is called anyways and idx will be 0
  if idx > 0
    var scheme = getbufline(winbufnr(main_id), idx)[0]
    exe $'colorscheme {scheme}'
    &background = current_background
    hi link PopupSelected PmenuSel
  endif
enddef

def PopupFilterColor(main_id: number, key: string, current_colorscheme: string, current_background: string): bool
  if key == "\<esc>"
    ClosePopups(main_id, -1)
    exe $'colorscheme {current_colorscheme}'
    return true
  else
    popup_filter_menu(main_id, key)
    ShowColorscheme(main_id, current_background)
    return true
  endif
enddef
#
# -------- MAIN
def ShowPopup(title: string, results: list<string>, search_type: string, search_pattern: string = '')

  # TODO: why you have the ^@ at the beginning of execute('colorscheme') ???
  var current_colorscheme = execute('colorscheme')->substitute('\n', '', 'g')
  var current_background = &background
  hi link PopupSelected PmenuSel

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
  # var main_id = popup_create(results, opts)

  # Preview handling
  var preview_id = -1
  var show_preview = false
  if search_type == 'file'
    show_preview = get(g:poptools_config, 'preview_file', true)
  elseif search_type == 'file_in_path'
    show_preview = get(g:poptools_config, 'preview_file_in_path', true)
  elseif search_type == 'recent_files'
    show_preview = get(g:poptools_config, 'preview_recent_files', true)
  elseif search_type == 'buffer'
    show_preview = get(g:poptools_config, 'preview_buffers', true)
  elseif search_type == 'grep'
    show_preview = get(g:poptools_config, 'preview_grep', true)
  endif

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
    opts.col = popup_width + popup_width / 2 + 2
    preview_id = popup_create("Something went wrong.
          \ Run :call popup_clear() to close.", opts)

    # Options for main_id, will be set later on
    opts.filter = (id, key) => PopupFilter(id, preview_id, key, search_type,
      search_pattern)

    # TODO Study how popus are sized and positioned on screen
    # If too many results, the scrollbar overlap the preview popup
    var scrollbar_contrib = len(results) > opts.minheight ? 1 : 0
    opts.col = popup_width - popup_width / 2 - 2 - scrollbar_contrib

    UpdateFilePreview(main_id, preview_id, search_type, search_pattern)
  endif

  if search_type == 'color'
    opts.filter = (id, key) => PopupFilterColor(id, key, current_colorscheme,
      current_background)
    var init_highlight_location = index(results, current_colorscheme)
    win_execute(main_id, $'norm {init_highlight_location }j')
  endif

  # Callback switch for main popup
  var PopupCallback: func
  if index(['file', 'file_in_path', 'recent_files', 'buffer'],
        \ search_type) != -1
    PopupCallback = (id, idx) => PopupCallbackFileBuffer(id, preview_id, idx)
  elseif search_type == 'dir'
    PopupCallback = PopupCallbackDir
  elseif search_type == 'history'
    PopupCallback = (id, idx) => PopupCallbackHistory(id, preview_id, idx)
  elseif search_type == 'grep'
    PopupCallback = (id, idx) => PopupCallbackGrep(id, preview_id, idx)
  elseif search_type == 'color'
    PopupCallback = PopupCallbackColorscheme
  endif

  opts.callback = PopupCallback
  popup_setoptions(main_id, opts)

enddef

# ---- API. The following functions are associated to commands in the plugin
#  file.
export def FindFile(search_type: string)
  # Guard
  if (search_type == 'file' || search_type == 'file_in_path')
        \  && getcwd() == expand('~')
    Echoerr("You are in your home directory. Too many results.")
    return
  endif

  # Main
  var what = input($"'{fnamemodify(getcwd(), ':~')}'\nFile name to search ('enter' for all): ")
  var hidden = what[0] == '.' ? '' : '*'

  var search_dir = ''
  if (search_type == 'file' || search_type == 'file_in_path')
    var current_wildmenu = &wildmenu
    set nowildmenu
    search_dir = input($"\n in which directory (you can use 'tab'): ", './', 'dir')
    if empty(search_dir) || search_dir == './'
      search_dir = getcwd()
    endif
    &wildmenu = current_wildmenu
  endif
  var results = getcompletion($'{search_dir}/**/{hidden}{what}',
        \  search_type, true)

  redraw
  echo "If the search takes too long hit CTRL-C few times and try to
        \ narrow down your search."
  if empty(results)
    echo $"'{what}' pattern not found!"
  else
    # OBS: the title MUST have filepath followed by \s because it is used to
    # reconstruct the full path filename
    var title = $" {fnamemodify(getcwd(), ':~')} - Files '{what}': "
    if empty(what)
      title = $" {fnamemodify(getcwd(), ':~')} - Search results for Files: "
    endif

    results ->filter('v:val !~ "\/$"')
      ->filter((_, val) => filereadable(expand(val)))
      ->map((_, val) => fnamemodify(val, ':.'))
    ShowPopup(title, results, search_type)
  endif
enddef

export def FindDir()
  # Main
  var what = input($"'{fnamemodify(getcwd(), ':~')}'\nDir name to search ('enter' for all): ")
  var hidden = what[0] == '.' ? '' : '*'

  var results = getcompletion($'**/{hidden}{what}',
        \  'dir', true)

  if empty(results)
    echo $"'{what}' pattern not found!"
  else
    # OBS: the title MUST have filepath followed by \s because it is used to
    # reconstruct the full path filename
    var title = $" {fnamemodify(getcwd(), ':~')} - Directories '{what}': "
    if empty(what)
      title = $" {fnamemodify(getcwd(), ':~')} - Search results for Directories: "
    endif
    ShowPopup(title, results, 'dir')
  endif
enddef

export def Vimgrep()
  # Guard
  if getcwd() == expand('~')
    Echoerr("You are in your home directory. Too many results.")
    return
  endif

  # Main
  var what = input($"'{fnamemodify(getcwd(), ':~')}'\n String to find: ")
  if empty(what)
    return
  endif

  var files = input($"\n in which files ('empty' for current file,
        \  '*' for all files): ", '*.')
  if empty(files)
    files = '%'
  else
    files = $'**/{files}'
  endif

  var vimgrep_options = input($" Vimgrep options (empty = 'gj'): ", 'gj')

  var cmd = $'vimgrep /{what}/{vimgrep_options} {files}'
  redraw
  echo cmd
  exe cmd
  copen
enddef

export def GrepInBuffer()
  # The format is like grep, i.e. filename:linenumber:
  # Main
  var what = input("Find in current buffer: ")
  if empty(what)
    return
  endif

  var initial_pos = getcursorcharpos()
  cursor(1, 1)
  var curr_line = line('.')
  var results = []
  while curr_line != 0
    curr_line = search(what, 'W')
    add(results, $'{expand("%:.")}:{curr_line}:')
  endwhile
  remove(results, -1)
  setcursorcharpos(initial_pos[1], initial_pos[2], initial_pos[3])

  var title = $" {fnamemodify(getcwd(), ':~')} - Search results for '{what}': "

  ShowPopup(title, results, 'grep', what)
enddef


export def Grep()
  # Guard
  if getcwd() == expand('~')
    Echoerr("You are in your home directory. Too many results.")
    return
  endif

  # Main
  var what = input($"'{fnamemodify(getcwd(), ':~')}'\n String to find: ")
  if empty(what)
    return
  endif

  var files = expand('%:t')
  var search_dir = expand('%:h')

  files = input($"\n in which files ('*' for all files): ", '*.')
  var current_wildmenu = &wildmenu
  set nowildmenu
  search_dir = input($"\n in which directory (you can use 'tab'): ",
        \  './', 'dir')
  if empty(search_dir) || search_dir == './'
    search_dir = getcwd()
  endif
  &wildmenu = current_wildmenu


  # External search command definitions
  var cmd_win_default = $'powershell -NoProfile -ExecutionPolicy Bypass
  \ -Command "cd {search_dir};findstr /C:{shellescape(what)} /N /S {files}"'
  # var cmd_win_default = $'powershell -NoProfile -ExecutionPolicy Bypass
  # -Command "cd {search_dir};findstr /C:{shellescape(what)} /N /S
  #  {files}|findstr /V /R \"^\\..*\\\\\""'
  #  The following is faster because it uses cmd.exe
  # var cmd_win_default = $'cmd.exe /c cd {shellescape(search_dir)} && findstr
  # /C:{shellescape(what)} /N /S {files} | findstr /V /R "^\..*\\\\"'
  var cmd_nix_default = $'cd {search_dir} && grep -n -r
        \ --include="{files}" "{what}" .'

  # TODO: fix this crap! User cannot decide commands!
  var cmd_win = get(g:poptools_config, 'grep_cmd_win', cmd_win_default)
  var cmd_nix = get(g:poptools_config, 'grep_cmd_nix', cmd_nix_default)

  # clean up the command-line
  redraw

  # Get results
  var results = []
  if has('win32')
    # In windows we get rid of the ^M and we filter eventual blank lines
    # results = systemlist(cmd_win)->map((_, val) => substitute(val, '\r', '',
    # 'g'))->filter('v:val != ""')
    echom cmd_win
    results = systemlist(cmd_win)
  else
    echom cmd_nix
    results = systemlist(cmd_nix)
  endif

  # OBS: the 'title' MUST have filepath followed by \s because it is used to
  # reconstruct the full path filename in the Callbacks and the show preview
  # mechanism
  var title = $" {fnamemodify(search_dir, ':~')}
        \  - Grep results for '{what}' in '{files}': "
  # echom matchstr(expand(results[1]), '^\S\{-}\ze:')
  if !empty(results)
    # Results from grep are given in the form path/to/file.ext:num: and we
    # have to extract only the filename from there
    results->matchstr('^\S\{-}\ze:')
      ->filter((_, val) => filereadable(expand(string(val))))
      ->map((_, val) => substitute(val, '^\S\{-}\ze:', (m) =>
        fnamemodify(m[0], ':.'), 'g'))

    ShowPopup(title, results, 'grep', what)
  else
    Echoerr($"\n pattern '{what}' not found!")
  endif
enddef

export def Buffers()
  var results = getcompletion('', 'buffer', true)
    ->map((_, val) => fnamemodify(val, ':.'))
  var title = " Buffers: "
  ShowPopup(title, results, 'buffer')
enddef

export def Colorscheme()
  hi link PopupSelected PmenuSel
  var results = getcompletion('', 'color', true)
  var title = " Colorschemes: "
  ShowPopup(title, results, 'color')
enddef

export def RecentFiles()
  var results =  copy(v:oldfiles)
    ->filter((_, val) => filereadable(expand(val)))
    ->map((_, val) => fnamemodify(val, ':.'))
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

export def LastSearch()
  if empty(last_results)
    Echoerr('No last search results available!')
  else
    ShowPopup(last_title, last_results, last_search_type, last_search_pattern)
  endif
enddef
