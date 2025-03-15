vim9script

# TODO Exclude 'wildignore' paths in Grep (it uses an external program)

# This must be persistent across different calls and therefore we explicitly
# assign a number
var last_results = []
var last_title = ''
var last_search_type = ''
var last_what = ''

var main_id: number
var prompt_id: number
var preview_id: number

var prompt_cursor: string
var prompt_sign: string
var prompt_text: string

# User defined settings through g:poptools_config
var fuzzy_search: bool
var preview_syntax: bool

var what: string
var items: string
var search_dir: string

var grep_inc_search: bool
# Hide cursor when operating in the popups
var gui_cursor: list<dict<any>>

def Echoerr(msg: string)
  echohl ErrorMsg | echom $"[poptools] {msg}" | echohl None
enddef

def Echowarn(msg: string)
  echohl WarningMsg | echom $"[poptools] {msg}" | echohl None
enddef

def InitScriptLocalVars()
  # Set script-local variables

  main_id = -1
  prompt_id = -1
  preview_id = -1

  prompt_cursor = '▏'
  prompt_sign = '> '
  prompt_text = ''

  what = ''
  items = ''
  search_dir = ''

  if exists('g:poptools_config') && has_key(g:poptools_config,
      'preview_syntax')
    preview_syntax = g:poptools_config['preview_syntax']
  else
    preview_syntax = true
  endif

  if exists('g:poptools_config') && has_key(g:poptools_config,
      'grep_inc_search')
    grep_inc_search = g:poptools_config['grep_inc_search']
  else
    grep_inc_search = true
  endif

  if exists('g:poptools_config') && has_key(g:poptools_config, 'fuzzy_search')
    fuzzy_search = g:poptools_config['fuzzy_search']
  else
    fuzzy_search = true
  endif

  if empty(prop_type_get('PopupToolsMatched'))
    prop_type_add('PopupToolsMatched', {highlight: 'WarningMsg'})
  endif
enddef

def RestoreCursor()
  set t_ve&
  if hlget("Cursor")[0]->get('cleared', false)
    hlset(gui_cursor)
  endif
enddef

# ----- Callback functions ------------------------
def PopupCallbackGrep(id: number, idx: number)
  if idx > 0
    popup_close(prompt_id, -1)
    if preview_id != -1
      popup_close(preview_id, -1)
    endif

    var selection = getbufline(winbufnr(main_id), idx)[0]
    # grep return format is 'file.xyz:76: ...'
    # You must extract the filename and the line number.
    # However, the name is not full, and you must reconstruct. The easiest
    # way is to fetch it from the popup title
    #
    # OBS! You could use split(selection, ':') to separate filename from line
    # number, but what if a filename is 'foo:bar'?
    var filename = selection->matchstr('^.*\ze:\d')
    var line = selection->matchstr('^.\{-}:\zs\d*\ze:')

    var path = split(popup_getoptions(id).title)[0]
    try
      if getcwd() == path
        exe $'edit {path}/{filename}'
      else
        exe $'edit {filename}'
      endif
    catch
      ClosePopups()
      Echoerr($'Cannot open {filename}')
    endtry

    cursor(str2nr(line), 1)
    RestoreCursor()
  endif
enddef

def PopupCallbackFileBuffer(id: number, idx: number)
  if idx > 0
    popup_close(prompt_id, -1)
    if preview_id != -1
      popup_close(preview_id, -1)
    endif
    echo ""
    var selection = getbufline(winbufnr(main_id), idx)[0]
    exe $'edit {selection}'
    RestoreCursor()
  endif
enddef

def PopupCallbackHistory(id: number, idx: number)
  if idx > 0
    popup_close(prompt_id, -1)
    if preview_id != -1
      popup_close(preview_id, -1)
    endif
    var cmd = getbufline(winbufnr(main_id), idx)[0]
    feedkeys(cmd)
    RestoreCursor()
  endif
enddef

def PopupCallbackDir(id: number, idx: number)
  if idx > 0
    var dir = getbufline(winbufnr(main_id), idx)[0]
    exe $'cd {dir}'
    pwd
    popup_close(prompt_id, -1)
    RestoreCursor()
  endif
enddef

def PopupCallbackColorscheme(id: number, idx: number)
  if idx > 0
    var scheme = getbufline(winbufnr(main_id), idx)[0]
    noa exe $'colorscheme {scheme}'
    popup_close(prompt_id, -1)
    RestoreCursor()
  endif
enddef

def UpdateFilePreview(search_type: string)
  # You  may use external programs to count the lines if 'readfile()' is too
  # slow, e.g.
  # var file_length = has('win32') ? str2nr(system('...')) :
  # str2nr(system($'wc
  # -l {filename}')->matchstr('\s*\zs\d*'))
  # var buf_lines = has('win32')
  #   ? systemlist($'powershell -c "Get-Content {filename} | Select-Object
  #   -Skip
  #   ({firstline} - 1) -First ({lastline} - {firstline} + 1)"')
  #   : systemlist($'sed -n "{firstline},{lastline}p" {filename}')
  #
  # For the syntax highlight, you may use the 'GetFiletypeByFilename()'
  # function, which is now in unused.vim
  #
  # Parse the highlighted line on the main popup
  var idx = line('.', main_id)

  # This 'if' is needed because the filter is called on <cr> anyways
  if idx > 0
    # The lines of main_id may be of the form 'filenames'
    # or 'filenames:lines:text'
    var filename = index(['grep', 'vimgrep'], search_type) != -1
      ? getbufline(winbufnr(main_id), idx)[0]->matchstr('^.*\ze:\d')
      : getbufline(winbufnr(main_id), idx)[0]

    var line_nr = index(['grep', 'vimgrep'], search_type) != -1
      ? str2nr(getbufline(winbufnr(main_id), idx)[0]->matchstr(':\zs\d*\ze:'))
      : popup_getpos(main_id).core_height / 2

    # We split the fullname so that we can show it nicely in the popup.
    # However, when showing the preview or during the callback, it is safer to
    # have the fullname. The path is in the popup title.
    # In case of Buffers or Recent files, that is not needed
    if index(['file', 'file_in_path', 'grep', 'vimgrep'], search_type) != -1
      var path = split(popup_getoptions(main_id).title)[0]
      if getcwd() == path
        filename = $'{path}/{filename}'
      endif
    endif

    var file_content = []
    if bufexists(filename)
      # The quickfix list load the buffers, but they have no content yet
      if empty(getqflist())
        file_content = getbufline(filename, 1, '$')
      else
        file_content = readfile($'{filename}')
      endif
    elseif filereadable($'{filename}')
      file_content = readfile($'{filename}')
    else
      file_content = ["Can't preview the file!"]
    endif

    # Set options
    win_execute(preview_id, $'setlocal number')
    # TODO: the wrap thing may be selectable through g:poptools_config?
    # win_execute(preview_id, '&wrap = false')

    # clean the preview
    popup_settext(preview_id, repeat([""], popup_getpos(main_id).core_height))
    # populate the preview
    setwinvar(preview_id, 'buf_lines', file_content)
    win_execute(preview_id, 'append(0, w:buf_lines)')
    # Unfold stuff
    win_execute(preview_id, 'norm! zR')

    # Syntax highlight if it creates problems, disable it. It is not
    # bulletproof
    if preview_syntax
      # set 'synmaxcol' for avoiding crashing if some readable file has
      # embedded figures.
      # Figure generate lines with >80000 columns and the internal engine
      # to figure out the syntax will fail.
      var old_synmaxcol = &synmaxcol
      &synmaxcol = 300
      var buf_extension = $'{fnamemodify(filename, ":e")}'
      var found_filetypedetect_cmd =
        autocmd_get({group: 'filetypedetect'})
        ->filter($'v:val.pattern =~ "*\\.{buf_extension}$"')
      var set_filetype_cmd = empty(found_filetypedetect_cmd)
        ? '&filetype = ""'
        : found_filetypedetect_cmd[0].cmd
      win_execute(preview_id, set_filetype_cmd)
      &synmaxcol = old_synmaxcol
    endif

    # Highlight grep matches
    if !empty(what)
      win_execute(preview_id, $'normal! {line_nr}gg')
      win_execute(preview_id, 'setlocal cursorline')
      win_execute(preview_id, $'match Search /{what}/')
    endif

    # Set preview ID title
    var preview_id_opts = popup_getoptions(preview_id)
    preview_id_opts.title = $' {fnamemodify(filename, ':t')} '
    popup_setoptions(preview_id, preview_id_opts)
  endif
enddef

export def ClosePopups()
  # This function tear down everything
  if preview_id != -1
    popup_close(preview_id, -1)
  endif
  popup_close(main_id, -1)
  popup_close(prompt_id, -1)
  RestoreCursor()
  prop_type_delete('PopupToolsMatched')
enddef

def PopupFilter(id: number,
    key: string,
    results: list<string>,
    search_type: string,
    current_colorscheme: string,
    current_background: string,
    ): bool

  # Save for last search
  if index(['file', 'file_in_path', 'grep', 'vimgrep'], search_type) != -1
    last_results = getbufline(winbufnr(main_id), 1, '$')
    last_title = popup_getoptions(main_id).title
    last_search_type = search_type
    last_what = what
  endif

  var maxheight = popup_getoptions(main_id).maxheight

  if key == "\<esc>"
    if search_type == 'colorscheme'
      exe $'colorscheme {current_colorscheme}'
    endif
    ClosePopups()
    return true
  endif

  # For debugging
  # echo 'Pressed key: ' .. key
  echo ''
  # You never know what the user can type... Let's use a try-catch
  try
    if key == "\<CR>"
      popup_close(main_id, getcurpos(main_id)[1])
      ClosePopups()
    elseif index(["\<Right>", "\<PageDown>"], key) != -1
      win_execute(main_id, 'normal! ' .. maxheight .. "\<C-d>")
    elseif index(["\<Left>", "\<PageUp>"], key) != -1
      win_execute(main_id, 'normal! ' .. maxheight .. "\<C-u>")
    elseif key == "\<Home>"
      win_execute(main_id, "normal! gg")
    elseif key == "\<End>"
      win_execute(main_id, "normal! G")
    elseif index(["\<tab>", "\<C-n>", "\<Down>", "\<ScrollWheelDown>"], key)
        != -1
      var ln = getcurpos(main_id)[1]
      win_execute(main_id, "normal! j")
      if ln == getcurpos(main_id)[1]
        win_execute(main_id, "normal! gg")
      endif
    elseif index(["\<S-Tab>", "\<C-p>", "\<Up>", "\<ScrollWheelUp>"], key) !=
        -1
      var ln = getcurpos(main_id)[1]
      win_execute(main_id, "normal! k")
      if ln == getcurpos(main_id)[1]
        win_execute(main_id, "normal! G")
      endif
    # The real deal: take a single, printable character
    elseif key =~ '^\p$' || keytrans(key) ==# "<BS>" || key == "\<c-u>"
      if key =~ '^\p$'
        prompt_text ..= key
      elseif keytrans(key) ==# "<BS>"
        if len(prompt_text) > 0
          prompt_text = prompt_text[: -2]
        endif
      elseif key == "\<c-u>"
        prompt_text = ""
      endif

      popup_settext(prompt_id, $'{prompt_sign}{prompt_text}{prompt_cursor}')

      # What you pass to popup_settext(main_id, ...) is a list of strings with
      # text properties attached, e.g.
      #
      # [
      #   { "text": "filename.txt",
      #     "props": [ {"col": 2, "length": 1, "type": "PopupToolsMatched"},
      #     ... ]
      #   },
      #   { "text": "another_file.txt",
      #     "props": [ {"col": 1, "length": 1, "type": "PopupToolsMatched"},
      #     ... ]
      #   },
      #   ...
      # ]
      #
      var filtered_results_full = []
      var filtered_results: list<dict<any>>

      if !empty(prompt_text)
        if fuzzy_search
          filtered_results_full = results->matchfuzzypos(prompt_text)
          var pos = filtered_results_full[1]
          filtered_results = filtered_results_full[0]
            ->map((ii, match) => ({
              text: match,
              props: pos[ii]->copy()->map((_, col) => ({
                col: col + 1,
                length: 1,
                type: 'PopupToolsMatched'
              }))}))
        else
          filtered_results_full = copy(results)
            ->map((_, text) => matchstrpos(text,
                  \ '\V' .. $"{escape(prompt_text, '\')}"))
            ->map((idx, match_info) => [results[idx], match_info[1],
              match_info[2]])

          filtered_results = copy(filtered_results_full)
            ->map((_, val) => ({
              text: val[0],
              props: val[1] >= 0 && val[2] >= 0
                ? [{
                  type: 'PopupToolsMatched',
                  col: val[1] + 1,
                  end_col: val[2] + 1
                }]
                : []
            }))
            ->filter("!empty(v:val.props)")
        endif
      endif

      var opts = popup_getoptions(prompt_id)
      var num_hits = !empty(filtered_results)
        ? len(filtered_results)
        : len(results)
      var base_title = trim(opts.title->matchstr('.*\ze('))
      opts.title = $' {base_title} ({num_hits}) '
      popup_setoptions(prompt_id, opts)

      if !empty(prompt_text)
        popup_settext(main_id, filtered_results)
      else
        popup_settext(main_id, results)
      endif
    else
      Echowarn('Unknown key')
    endif
  catch
    ClosePopups()
    Echoerr('Internal error')
  endtry

  if preview_id != -1
    UpdateFilePreview(search_type)
  endif

  if search_type == 'colorscheme'
    ShowColorscheme(current_background)
  endif

  return true
enddef

def ShowColorscheme(current_background: string)
  # Circular selection
  var idx = line('.', main_id) % (line('$', main_id) + 1)
  # TODO: check
  # I need this check because when user makes a selection with <cr> this
  # function is called anyways and idx will be 0
  if idx > 0
    var scheme = getbufline(winbufnr(main_id), idx)[0]
    exe $'colorscheme {scheme}'
    &background = current_background
    hi link PopupSelected PmenuSel
  endif
enddef

def ShowPromptPopup(results: list<string>,
    search_type: string)
  # This is the UI thing
  var main_id_core_line = popup_getpos(main_id).core_line
  var main_id_core_col = popup_getpos(main_id).core_col
  var main_id_core_width = popup_getpos(main_id).core_width

  var base_title = $'{search_type}:'
  var opts = {
    minwidth: main_id_core_width,
    maxwidth: main_id_core_width,
    line: main_id_core_line - 3,
    col: main_id_core_col - 1,
    borderchars: ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
    border: [1, 1, 0, 1],
    mapping: 0,
    scrollbar: 0,
    wrap: 0,
    drag: 0,
  }

  # Filter
  var current_colorscheme = execute('colorscheme')->substitute('\n', '', 'g')
  var current_background = &background
  opts.filter = (id, key) => PopupFilter(id, key, results, search_type,
    current_colorscheme, current_background)

  var num_hits = len(getbufline(winbufnr(main_id), 1, "$"))
  if empty(what)
    opts.title = $' {base_title} ({num_hits}) '
  else
    opts.title = $' {base_title} "{what}" ({num_hits}) '
  endif

  prompt_text = ""
  prompt_id = popup_create([prompt_sign .. prompt_cursor], opts)

enddef

# ----- MAIN -----
def ShowPopup(results: list<string>,
    search_type: string,
    title: string = '')
  # This function is regarded as main function. It is called once
  # the 'results' list is ready.
  # Clean up the command line to avoid 'Press Enter' otherwise the popups will
  # not show up
  redraw

  # For some reason you get ^@ (=newline)
  var current_colorscheme = execute('colorscheme')->substitute('\n', '', 'g')
  var current_background = &background
  hi link PopupSelected PmenuSel

  # hide cursor
  set t_ve=
  gui_cursor = hlget("Cursor")
  hlset([{name: 'Cursor', cleared: true}])

  # Assuming no-preview
  var popup_width = (&columns * 2) / 3
  var popup_height = &lines / 2

  # Standard options
  var opts = {
    pos: 'center',
    border: [1, 1, 1, 1],
    borderchars:  ['─', '│', '─', '│', '├', '┤', '╯', '╰'],
    maxheight: popup_height,
    minheight: popup_height,
    minwidth: popup_width,
    maxwidth: popup_width,
    scrollbar: 0,
    cursorline: 1,
    mapping: 0,
    wrap: 0,
    drag: 0,
  }

  if !empty(title)
    opts.title = title
  endif

  main_id = popup_create(results, opts)

  # Preview handling
  var show_preview = false
  if search_type == 'file'
    if exists('g:poptools_config') && has_key(g:poptools_config,
        'preview_file')
      show_preview = g:poptools_config['preview_file']
    endif
  elseif search_type == 'file_in_path'
    if exists('g:poptools_config')
        && has_key(g:poptools_config, 'preview_file_in_path')
      show_preview = g:poptools_config['preview_file_in_path']
    endif
  elseif search_type == 'recent_files'
    if exists('g:poptools_config')
        && has_key(g:poptools_config, 'preview_recent_files')
      show_preview = g:poptools_config['preview_recent_files']
    endif
  elseif search_type == 'buffer'
    if exists('g:poptools_config')
        && has_key(g:poptools_config, 'preview_buffers')
      show_preview = g:poptools_config['preview_buffers']
    endif
  elseif search_type == 'grep'
    if exists('g:poptools_config') && has_key(g:poptools_config,
        'preview_grep')
      show_preview = g:poptools_config['preview_grep']
    endif
  elseif search_type == 'vimgrep'
    if exists('g:poptools_config') && has_key(g:poptools_config,
        'preview_vimgrep')
      show_preview = g:poptools_config['preview_vimgrep']
    endif
  endif

  if show_preview
    # Some geometry: we want more room in case of preview
    popup_width = (&columns * 9) / 10
    popup_height = (&lines * 7) / 10
    var left_margin = 8

    # Adjustments for the main popup
    opts.pos = 'topleft'
    opts.minwidth = float2nr(0.4 * popup_width)
    opts.maxwidth = float2nr(0.4 * popup_width)
    opts.maxheight = popup_height
    opts.minheight = popup_height
    opts.line = 6
    # opts.col = &columns / 2 - opts.minwidth - 1
    opts.col = left_margin

    # Adjustments for the preview popup
    var preview_opts = copy(opts)
    preview_opts.pos = 'topleft'
    preview_opts.line = opts.line - 2
    preview_opts.col = left_margin + opts.maxwidth + 2
    preview_opts.minwidth = float2nr(0.6 * popup_width)
    preview_opts.maxwidth = float2nr(0.6 * popup_width)
    preview_opts.maxheight = opts.minheight + 2
    preview_opts.minheight = opts.minheight + 2
    preview_opts.cursorline = 0

    preview_opts.borderchars = ['─', '│', '─', '│', '╭', '╮', '╯', '╰']
    preview_id = popup_create("Something went wrong."
      .. "Run :call popup_clear() to close.", preview_opts)

    UpdateFilePreview(search_type)
  endif

  if search_type == 'colorscheme'
    var init_highlight_location = index(results, current_colorscheme)
    win_execute(main_id, $'norm {init_highlight_location }j')
  endif

  # Callback switch for main_id
  var PopupCallback: func
  if index(['file', 'file_in_path', 'recent_files', 'buffer'],
        \ search_type) != -1
    PopupCallback = PopupCallbackFileBuffer
  elseif search_type == 'dir'
    PopupCallback = PopupCallbackDir
  elseif search_type == 'history'
    PopupCallback = PopupCallbackHistory
  elseif  index(['grep', 'vimgrep'], search_type) != -1
    PopupCallback = PopupCallbackGrep
  elseif search_type == 'colorscheme'
    PopupCallback = PopupCallbackColorscheme
  endif

  opts.callback = PopupCallback
  popup_setoptions(main_id, opts)

  ShowPromptPopup(results, search_type)
enddef

# ---- API ------------
# The following functions are associated to commands in the plugin file.
# They are used to generate the 'results' list to pass to ShowPopup()
export def FindFile(search_type: string)
  InitScriptLocalVars()
  # Guard
  if (search_type == 'file' || search_type == 'file_in_path')
        \  && getcwd() == expand('~')
    Echoerr("You are in your home folder. Too many results.")
    return
  endif

  # Main
  what = input($"current folder: '{fnamemodify(getcwd(), ':~')}'\nFile name to
        \ search ('enter' for all): ")
  var hidden = what[0] == '.' ? '' : '*'

  search_dir = '.'
  if (search_type == 'file')
    var current_wildmenu = &wildmenu
    set nowildmenu
    search_dir = input($"\nin which folder (you can also use 'tab'): ",
      './**', 'dir')
    if empty(search_dir) || search_dir == './'
      search_dir = getcwd()
    endif
    &wildmenu = current_wildmenu
  endif
  var results = getcompletion($'{search_dir}/{hidden}{what}',
        \  search_type, true)
  # echo "\n[poptools] If the search takes too long hit CTRL-C few times and
  # try to
  #       \ narrow down your search."

  if empty(results)
    echo $"'{what}' pattern not found!"
  else
    # OBS: the title MUST have filepath followed by \s because it is used to
    # reconstruct the full path filename
    var title = $" {fnamemodify(getcwd(), ':~')} - Files '{what}': "
    if empty(what)
      title = $" {fnamemodify(getcwd(), ':~')}: "
    endif

    results ->filter('v:val !~ "\/$"')
      ->filter((_, val) => filereadable(expand(val)))
      ->map((_, val) => fnamemodify(val, ':.'))
    ShowPopup(results, search_type, title)
  endif
enddef

export def FindDir()
  InitScriptLocalVars()
  if getcwd() == expand('~')
    Echoerr("You are in your home folder. Too many results.")
    return
  endif

  what = input($"current folder: '{fnamemodify(getcwd(), ':~')}'\n
        \Folder name to search ('enter' for all): ")
  var hidden = what[0] == '.' ? '' : '*'

  var results = getcompletion($'**/{hidden}{what}', 'dir', true)

  if empty(results)
    echo $"'{what}' pattern not found!"
  else
    # OBS: the title MUST have filepath followed by \s because it is used to
    # reconstruct the full path filename
    var title = $" {fnamemodify(getcwd(), ':~')} - Directories '{what}': "
    if empty(what)
      title = $" {fnamemodify(getcwd(), ':~')}: "
    endif
    ShowPopup(results, 'dir', title)
  endif
enddef

def Qf2Results(): list<string>
  var qf_results = getqflist()
  var results = qf_results
    ->mapnew((_, val) => ($'{fnamemodify(bufname(val.bufnr), ':p')}'
    .. $':{val.lnum}:{val.text}'))
  return results
enddef

export def Vimgrep()
  InitScriptLocalVars()
  # Guard
  if getcwd() == expand('~')
    Echoerr("You are in your home folder. Too many results.")
    return
  endif

  # Main
  if grep_inc_search
    GrepInBufferHighlight()
  endif
  what = input($"current folder: '{fnamemodify(getcwd(), ':~')}'\n
        \String to find: ")
  GrepInBufferHighlightClear()
  if empty(what)
    return
  endif

  items = input($"\nin which files ('empty' for current file,
        \  '*' for all files): ", '*.')
  if empty(items)
    items = '%'
    search_dir = ''
  else
    # vimgrep does not like non-escaped spaces. We also have to remove the
    # final \ or / in case the user type a folder with a final / or \,
    # e.g. '~\Saved Games\' shall be replaced with '~\Saved\ Games'
    var current_wildmenu = &wildmenu
    set nowildmenu
    search_dir = input($"\nin which folder(s) (you can use 'tab'): ", './**',
      'dir')
    ->escape(' ')
    ->substitute('\v(\\|/)$', '', '')
    &wildmenu = current_wildmenu
  endif

  var vimgrep_options = input("\nVimgrep options (g = every match, "
    .. "f = fuzzy): ", 'g')
  if empty(vimgrep_options)
    return
  endif

  # 'j' is to avoid jumping on the first match
  var cmd = $'vimgrep /{what}/j{vimgrep_options} {search_dir}/{items}'
  exe cmd
  var results = Qf2Results()->mapnew((_, val) => fnamemodify(val, ':.'))
  var title = $" {fnamemodify(getcwd(), ':~')}: "
  ShowPopup(results, 'vimgrep', title)
enddef

# These two functions are used to mimic the in_search feature for
# GrepInBuffer() function.
var match_id = 0
def GrepInBufferHighlight()
  augroup SEARCH_HI | autocmd!
    autocmd CmdlineChanged @ {
      if match_id > 0
        matchdelete(match_id)
      endif
      # cursor(1, 1)
      var line_nr = search(getcmdline(), 'w')
      var pattern = getcmdline()
      # Highlight only the current line
      var what_to_match = $'\%{line_nr}l{pattern}'
      # var what_to_match = $'{pattern}'
      match_id = matchadd('IncSearch', what_to_match)
      # Highlight all the matches instead or the current line
      # match_id = matchadd('Search', getcmdline())
      redraw
    }
    autocmd CmdlineLeave @ {
      if match_id > 0
        matchdelete(match_id)
        match_id = 0
      endif
    }
  augroup END
enddef

def GrepInBufferHighlightClear()
  if exists("#SEARCH_HI")
    autocmd! SEARCH_HI
    augroup! SEARCH_HI
  endif
  if match_id > 0
    matchdelete(match_id)
  endif
enddef

export def GrepInBuffer(what_user: string = '')
  InitScriptLocalVars()
  # The format is like grep, i.e. filename:linenumber:
  if empty(what_user)
    GrepInBufferHighlight()
    what = input("Find in current buffer: ")
    GrepInBufferHighlightClear()
    if empty(what)
      return
    endif
  else
    what = what_user
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

  var title = $" {fnamemodify(getcwd(), ':~')}: "
  ShowPopup(results, 'grep', title)
enddef


export def Grep()
  InitScriptLocalVars()
  # Guard
  if getcwd() == expand('~')
    Echoerr("You are in your home folder. Too many results.")
    return
  endif

  # Main
  if grep_inc_search
    GrepInBufferHighlight()
  endif
  what = input($"current folder: '{fnamemodify(getcwd(), ':~')}'\n
        \String to find: ")

  GrepInBufferHighlightClear()
  if empty(what)
    return
  endif

  items = input($"\nin which files ('*' for all files): ", '*.')
  var current_wildmenu = &wildmenu
  set nowildmenu
  search_dir = input($"\nin which folder (you can use 'tab'): ",
        \  './', 'dir')->substitute('\v(\\|/)$', '', '')
  if empty(search_dir) || search_dir == './'
    search_dir = getcwd()
  endif
  &wildmenu = current_wildmenu

  # Windows default
  var cmd_win_default = 'powershell -NoProfile -ExecutionPolicy Bypass '
    .. '-Command "& { findstr /C:''' .. what .. ''' /N /S '''
    .. fnamemodify($'{search_dir}\{items}', ':p') .. ''' }"'

  # *nix default
  var cmd_nix_default = $'grep -nrH --include="{items}" "{what}" {search_dir}'

  var cmd_win = cmd_win_default
  if exists('g:poptools_config') && has_key(g:poptools_config, 'grep_cmd_win')
    var search_dir_escaped = escape(search_dir, '\')
    cmd_win = g:poptools_config['grep_cmd_win']
      ->substitute("{search_dir}", search_dir_escaped, 'g')
      ->substitute("{items}", items, 'g')
      ->substitute("{what}", what, 'g')
  endif

  var cmd_nix = cmd_nix_default
  if exists('g:poptools_config') && has_key(g:poptools_config, 'grep_cmd_nix')
    cmd_nix = g:poptools_config['grep_cmd_nix']
      ->substitute("{search_dir}", search_dir, 'g')
      ->substitute("{items}", items, 'g')
      ->substitute("{what}", what, 'g')
  endif

  # clean up the command-line: needed!
  redraw

  # Get results
  var saved_grepprg = &grepprg
  if has('win32')
    &grepprg = cmd_win
    grep!
    echom getqflist({'title': 0}).title
  else
    &grepprg = cmd_nix
    grep!
    echom getqflist({'title': 0}).title
  endif
  &grepprg = saved_grepprg

  var qf_results = getqflist()
  var results = Qf2Results()->mapnew((_, val) => fnamemodify(val, ':.'))
  var title = $" {fnamemodify(getcwd(), ':~')}: "
  ShowPopup(results, 'grep', title)
enddef

export def Buffers()
  InitScriptLocalVars()
  var results = getcompletion('', 'buffer', true)
    ->map((_, val) => fnamemodify(val, ':.'))
  # var title = " Buffers: "
  ShowPopup(results, 'buffer')
enddef

export def Colorscheme()
  InitScriptLocalVars()
  hi link PopupSelected PmenuSel
  var results = getcompletion('', 'color', true)
  ShowPopup(results, 'colorscheme')
enddef

export def RecentFiles()
  InitScriptLocalVars()
  var results =  copy(v:oldfiles)
    ->filter((_, val) => filereadable(expand(val)))
    ->map((_, val) => fnamemodify(val, ':.'))
  ShowPopup(results, 'recent_files')
enddef

export def CmdHistory()
  InitScriptLocalVars()
  var results = split(execute('history :'), '\n')
  for ii in range(0, len(results) - 1)
    results[ii] = substitute(results[ii], '\v^\>?\s*\d*\s*(\w*)', ':\1', 'g')
  endfor
  ShowPopup(reverse(results[1 : ]), 'history')
enddef

export def LastSearch()
  if empty(last_results)
    Echoerr('No last search results available!')
  else
    ShowPopup(last_results, last_search_type, last_title)
  endif
enddef
