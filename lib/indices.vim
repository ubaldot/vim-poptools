vim9script

# TODO
# This script is copied and adapted from vim-markdown-extras. It could be
# better integrated with the rest of the plugin, but due to lack of time it has
# been kept as separate script and adjusted from the original source.

import autoload "./funcs.vim" as funcs

var index: any
var index_id: number = -1
var prompt_id: number = -1

var prompt_cursor = funcs.prompt_cursor
var prompt_sign = funcs.prompt_sign
var prompt_text = ''

var gui_index_cursor: list<dict<any>>

const URL_PREFIXES = [ 'https://', 'http://', 'ftp://', 'ftps://',
    'sftp://', 'telnet://', 'file://']

def IsURL(Link: string): bool
  for url_prefix in URL_PREFIXES
    if Link =~ $'^{url_prefix}'
      return true
    endif
  endfor
    return false
enddef

def RestoreIndexCursor()
  set t_ve&
  if hlget("Cursor")[0]->get('cleared', false)
    hlset(gui_index_cursor)
  endif
enddef

def CloseIndexPopups()
  # This function tear down everything
  popup_close(index_id, -1)
  popup_close(prompt_id, -1)
  RestoreIndexCursor()
  prop_type_delete('PopupToolsMatched')
enddef

def PopupIndexFilter(id: number,
    key: string,
    slave_id: number,
    results: list<string>,
    match_id: number = -1,
    ): bool

  # Copied from InitScriptVars()
  if empty(prop_type_get('PopupToolsMatched'))
    prop_type_add('PopupToolsMatched', {highlight: 'WarningMsg'})
  endif

  var maxheight = popup_getoptions(slave_id).maxheight

  if key == "\<esc>"
    if match_id != -1
      matchdelete(match_id)
    endif
    CloseIndexPopups()
    return true
  endif

  echo ''
  # You never know what the user can type... Let's use a try-catch
  # If you get an Internal Error is most likely somewhere here.
  try
    if key == "\<CR>"
      popup_close(slave_id, getcurpos(slave_id)[1])
      CloseIndexPopups()
    elseif index(["\<Right>", "\<PageDown>"], key) != -1
      win_execute(slave_id, 'normal! ' .. maxheight .. "\<C-d>")
    elseif index(["\<Left>", "\<PageUp>"], key) != -1
      win_execute(slave_id, 'normal! ' .. maxheight .. "\<C-u>")
    elseif key == "\<Home>"
      win_execute(slave_id, "normal! gg")
    elseif key == "\<End>"
      win_execute(slave_id, "normal! G")
    elseif index(["\<tab>", "\<C-n>", "\<Down>", "\<ScrollWheelDown>"], key)
        != -1
      var ln = getcurpos(slave_id)[1]
      win_execute(slave_id, "normal! j")
      if ln == getcurpos(slave_id)[1]
        win_execute(slave_id, "normal! gg")
      endif
    elseif index(["\<S-Tab>", "\<C-p>", "\<Up>", "\<ScrollWheelUp>"], key) !=
        -1
      var ln = getcurpos(slave_id)[1]
      win_execute(slave_id, "normal! k")
      if ln == getcurpos(slave_id)[1]
        win_execute(slave_id, "normal! G")
      endif
    # The real deal: take a single, printable character
    elseif key =~ '^\p$' || keytrans(key) ==# "<BS>" || key == "\<c-u>"
      if key =~ '^\p$'
        prompt_text ..= key
      elseif keytrans(key) ==# "<BS>"
        if strchars(prompt_text) > 0
          prompt_text = prompt_text[: -2]
        endif
      elseif key == "\<c-u>"
        prompt_text = ""
      endif

      popup_settext(id, $'{prompt_sign}{prompt_text}{prompt_cursor}')

      # What you pass to popup_settext(slave_id, ...) is a list of strings with
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
        if funcs.fuzzy_search
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

      var opts = popup_getoptions(id)
      var num_hits = !empty(filtered_results)
        ? len(filtered_results)
        : len(results)
      popup_setoptions(id, opts)

      if !empty(prompt_text)
        popup_settext(slave_id, filtered_results)
      else
        popup_settext(slave_id, results)
      endif
    else
      funcs.Echowarn('Unknown key')
    endif
  catch
    CloseIndexPopups()
    RestoreIndexCursor()
    funcs.Echoerr('Internal error')
  endtry

  return true
enddef

def ShowIndexPromptPopup(slave_id: number,
    links: list<string>,
    title: string,
    match_id: number = -1
  )
  # This could be called by other scripts and its id may be undefined.
  # This is the UI thing
  var slave_id_core_line = popup_getpos(slave_id).core_line
  var slave_id_core_col = popup_getpos(slave_id).core_col
  var slave_id_core_width = popup_getpos(slave_id).core_width

  # var base_title = $'{search_type}:'
  var opts = {
    title: title,
    minwidth: slave_id_core_width,
    maxwidth: slave_id_core_width,
    line: slave_id_core_line - 3,
    col: slave_id_core_col - 1,
    borderchars: ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
    border: [1, 1, 0, 1],
    mapping: 0,
    scrollbar: 0,
    wrap: 0,
    drag: 0,
  }

  # Filter
  opts.filter = (id, key) => PopupIndexFilter(id, key, slave_id, links, match_id)

  prompt_text = ""
  prompt_id = popup_create([prompt_sign .. prompt_cursor], opts)
enddef

def IndexCallback(id: number, idx: number)
  if idx > 0

    var selection = ''
    if typename(index) == "list<string>"
      selection = getbufline(winbufnr(id), idx)[0]
    elseif typename(index) == "list<list<string>>"
      selection = getbufline(winbufnr(id), idx)[0]
      var index_names = index->mapnew((_, val) => val[0])
      var ii = index(index_names, selection)
      selection = index[ii][1]
    elseif typename(index) == "dict<string>"
      var selection_key = getbufline(winbufnr(id), idx)[0]
      selection = index[selection_key]
    endif

    if !empty(selection)
      if IsURL(selection)
        exe $'Open {selection}'
      elseif filereadable(fnameescape(selection))
        exe $'edit {fnameescape(selection)}'
      elseif selection =~ "^function("
        try
          var Tmp = eval(selection)
          Tmp()
        catch
          RestoreIndexCursor()
          funcs.Echoerr("Function must be global")
        endtry
      endif
    endif

    popup_close(prompt_id, -1)

    index_id = -1
  endif
enddef

export def ShowIndex(passed_index: string='')
  var index_found = false

  if !empty(passed_index)
    # TODO: remove the eval() with something better
    index = eval(passed_index)
    index_found = true
  elseif exists('g:poptools_index') != 0
      && !empty('g:poptools_index')
    index = g:poptools_index
    index_found = true
  else
    funcs.Echoerr("Cannot find index" )
  endif

  if index_found
    # hide cursor
    set t_ve=
    gui_index_cursor = hlget("Cursor")
    hlset([{name: 'Cursor', cleared: true}])

    const popup_width = (&columns * 2) / 3
    const popup_height = min([len(index), &lines / 2])
    var opts = {
        pos: 'center',
        border: [1, 1, 1, 1],
        borderchars:  ['─', '│', '─', '│', '├', '┤', '╯', '╰'],
        minwidth: popup_width,
        maxwidth: popup_width,
        minheight: popup_height,
        maxheight: popup_height,
        scrollbar: 0,
        cursorline: 1,
        callback: IndexCallback,
        mapping: 0,
        wrap: 0,
        drag: 0,
      }
    if typename(index) == "list<string>"
      index_id = popup_create(index, opts)
      ShowIndexPromptPopup(index_id, index, " index: ")
    elseif typename(index) == "list<list<string>>"
      var index_names = index->mapnew((_, val) => val[0])
      index_id = popup_create(index_names, opts)
      ShowIndexPromptPopup(index_id, index_names, " index: ")
    elseif typename(index) == "dict<string>"
      index_id = popup_create(keys(index), opts)
      ShowIndexPromptPopup(index_id, keys(index), " index: ")
    else
      RestoreIndexCursor()
      funcs.Echoerr("Wrong argument type passed to ':PoptoolsIndex' "
            \ .. $" (you passed a {typename(index)})")
    endif
  endif
enddef
