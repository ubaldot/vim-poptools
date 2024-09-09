vim9script

var popup_width = &columns / 2
var popup_height = &lines / 2

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

def PopupCallbackColorscheme(id: number, idx: number)
  if idx != -1
    var scheme = getbufline(winbufnr(id), idx)[0]
    noa exe $'colorscheme {scheme}'
  endif
enddef

# ------- Filter functions
# You  may use external programs to count the lines if 'readfile()' is too
# slow, e.g.
# var file_length = has('win32') ? str2nr(system('...')) : str2nr(system($'wc -l {filename}')->matchstr('\s*\zs\d*'))
# var buf_lines = has('win32')
#   ? systemlist($'powershell -c "Get-Content {filename} | Select-Object -Skip ({firstline} - 1) -First ({lastline} - {firstline} + 1)"')
#   : systemlist($'sed -n "{firstline},{lastline}p" {filename}')
#
# For the syntax highlight, you may use the 'GetFiletypeByFilename()' function
#
def UpdateFilePreview(main_id: number, preview_id: number, search_pattern: string)
  # Parse the highlighted line on the main popup
  var idx = line('.', main_id)

  var filename = empty(search_pattern)
    ? getbufline(winbufnr(main_id), idx)[0]
    : getbufline(winbufnr(main_id), idx)[0]->matchstr('^\S\{-}\ze:')

  var line_nr = empty(search_pattern)
    ? popup_height / 2
    : str2nr(getbufline(winbufnr(main_id), idx)[0]->matchstr(':\zs\d*\ze:'))

  # Select the portion of buffer to show in the preview
  var file_content = readfile($'{expand(filename)}')

  var firstline = max([1, line_nr - popup_height / 2])
  var file_length = len(file_content)
  var lastline = min([file_length, line_nr + popup_height / 2])
  var buf_lines = file_content[firstline - 1 : lastline]

  # Add line numbers only to 'grep' because it messes up with the syntax, see
  # e.g. what happens with .md files
  if !empty(search_pattern)
    for ii in range(0, len(buf_lines) - 1)
      buf_lines[ii] = $'{firstline + ii}   {buf_lines[ii]}'
    endfor
  endif

  # Set filetype. No bulletproof, but is seems to work reasonably well
  var buf_extension = $'{fnamemodify(filename, ":e")}'
  var found_filetypedetect_cmd = autocmd_get({group: 'filetypedetect'})->filter($'v:val.pattern =~ "*\\.{buf_extension}$"')
  var set_filetype_cmd = empty(found_filetypedetect_cmd)
     ? '&filetype = ""'
     : found_filetypedetect_cmd[0].cmd

  # Clean the preview popup
  popup_settext(preview_id, repeat([""], popup_height))
  # populate the preview
  popup_settext(preview_id, buf_lines)
  #
  # TODO: Open all folds, it works only if you reselect the item in the popup
  # from below.
  win_execute(preview_id, $'norm! zR')
  #
  # Syntax highlight
  win_execute(preview_id, set_filetype_cmd)
  win_execute(preview_id, '&wrap = false')

  # Set preview ID title
  var preview_id_opts = popup_getoptions(preview_id)
  preview_id_opts.title = $' {filename} '
  popup_setoptions(preview_id, preview_id_opts)

  # Highlight search pattern
  if !empty(search_pattern)
    win_execute(preview_id, $'exe "match Search \"{search_pattern}\""')
  endif
enddef

def ShowColorscheme(main_id: number)
    var idx = line('.', main_id)
    var scheme = getbufline(winbufnr(main_id), idx)[0]
    exe $'colorscheme {scheme}'
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

def PopupFilter(main_id: number, preview_id: number, key: string, search_pattern: string): bool
  # Handle shortcuts
  if index(['j', "\<down>", "\<c-n>"], key) != -1
    win_execute(main_id, 'norm j')
    UpdateFilePreview(main_id, preview_id, search_pattern)
    return true
  elseif index(['k', "\<Up>", "\<c-p>"], key) != -1
    win_execute(main_id, 'norm k')
    UpdateFilePreview(main_id, preview_id, search_pattern)
    return true
  elseif key == "\<esc>"
    ClosePopups(main_id, preview_id)
    return true
  else
    return popup_filter_menu(main_id, key)
  endif
enddef

def PopupFilterColor(main_id: number, key: string, current_colorscheme: string): bool
  # Handle shortcuts
  if index(['j', "\<down>", "\<c-n>"], key) != -1
    win_execute(main_id, 'norm j')
    ShowColorscheme(main_id)
    return true
  elseif index(['k', "\<Up>", "\<c-p>"], key) != -1
    win_execute(main_id, 'norm k')
    ShowColorscheme(main_id)
    return true
  elseif key == "\<esc>"
    ClosePopups(main_id, -1)
    # TODO: BUG
    # exe $'colorscheme {current_colorscheme}'
    return true
  else
    return popup_filter_menu(main_id, key)
  endif
enddef
#
# -------- MAIN
def ShowPopup(title: string, results: list<string>, search_type: string, search_pattern: string = '')

  # TODO: why you have the ^@ at the beginning of execute('colorscheme') ???
  var current_colorscheme = execute('colorscheme')->substitute('\n', '', 'g')
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
    preview_id = popup_create("I AM THE PREVIEW! MWAHAHAHA!", opts)

    # Options for main_id, will be set later on
    opts.filter = (id, key) => PopupFilter(id, preview_id, key, search_pattern)
    # If too many results, the scrollbar overlap the preview popup
    var scrollbar_contrib = len(results) > opts.minheight ? 1 : 0
    opts.col = popup_width - popup_width / 2 - 2 - scrollbar_contrib

    UpdateFilePreview(main_id, preview_id, search_pattern)
  endif

  if search_type == 'color'
    opts.filter = (id, key) => PopupFilterColor(id, key, current_colorscheme)
    var init_highlight_location = index(results, current_colorscheme)
    win_execute(main_id, $'norm {init_highlight_location + 1}j')
  endif

  # Callback switch for main popup
  var PopupCallback: func
  if index(['file', 'file_in_path', 'recent_files', 'buffer'], search_type) != -1
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

# API. The following functions are associated to commands in the plugin file.
export def FindFileOrDir(search_type: string)
  # Guard
  if (search_type == 'file' || search_type == 'file_in_path') && getcwd() == expand('~')
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
    var title = $" {getcwd()}, {search_type}s '{substring}': "
    if empty(substring)
      title = $" Search results for {search_type}s in {getcwd()}: "
    endif

    if search_type == 'file' || search_type == 'file_in_path'
      results ->filter('v:val !~ "\/$"')
              ->filter((_, val) => filereadable(expand(val)))
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

  var files = input($"{getcwd()} - in which files: ")
  if empty(files)
    files = '*'
  endif

  var cmd = ''
  var search_dir = get(g:poptools_config, 'search_dir', $'{getcwd()}')
  if has('win32') && exists('+shellslash') && !&shellslash
    # on windows, need to handle backslash
    search_dir->substitute('\\', '/', 'g')
  endif

  var cmd_win_default = $'powershell -command "Set-Location -Path {search_dir};gci -Recurse -Filter {files} | Select-String -Pattern {what} -CaseSensitive"'
  var cmd_nix_default = $'grep -n -r --include="{files}" "{what}" {search_dir}'

  var cmd_win = get(g:poptools_config, 'grep_cmd_win', cmd_win_default)
  var cmd_nix = get(g:poptools_config, 'grep_cmd_nix', cmd_nix_default)

  redraw
  # Get results
  var results = []
  if has('win32')
    # In windows we get rid of the ^M and we filter eventual blank lines
    results = systemlist(cmd_win)->map((_, val) => substitute(val, '\r', '', 'g'))->filter('v:val != ""')
    echom cmd_win
  else
    # get rid of eventual blank lines
    results = systemlist(cmd_nix)->filter('v:val != ""')
    echom cmd_nix
  endif

  var title = $" {search_dir} - Grep results for '{what}': "
  ShowPopup(title, results, 'grep', what)
enddef

export def Buffers()
  var results = getcompletion('', 'buffer', true)
  var title = " Buffers: "
  ShowPopup(title, results, 'buffer')
enddef

export def Colorscheme()
  var results = getcompletion('', 'color', true)
  var title = " Colorschemes: "
  ShowPopup(title, results, 'color')
enddef

export def RecentFiles()
  var results =  copy(v:oldfiles)
    ->filter((_, val) => filereadable(expand(val)))
    # ENABLE IF YOU WANT RELATIVE PATH
    # ->map((_, val) => fnamemodify(val, ':.'))
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
