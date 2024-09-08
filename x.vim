vim9script noclear

var preview_popup = -1
 # UBA FREGNA

def PopupSelectCallback(id: number, idc: number)
  popup_close(preview_popup)
enddef

def UpdatePreview(id: any)
  # Set-text
  popup_close(preview_popup)
  var buf_nr = line('.', id)
  preview_popup = popup_create(buf_nr + 1, opts)
enddef

# UBA SBORRA

def PopupFilter(id: number, key: string): bool
  # Handle shortcuts
  if index(['j', "\<down>", "\<c-n>"], key) != -1
    win_execute(id, 'norm j')
    UpdatePreview(id)
    return true
  elseif index(['k', "\<Up>", "\<c-p>"], key) != -1
    win_execute(id, 'norm k')
    UpdatePreview(id)
    return true
  else
    return popup_filter_menu(id, key)
  endif
enddef

var menu_items = ['Option 1', 'Option 2', 'Option 3']
var popup_width = &columns / 3
var popup_height = &lines / 2

# If preview, then add filter in the options

var opts = {
  pos: 'topleft',
  line: popup_height - popup_height / 2,
  col: popup_width - popup_width / 2 - 2,
  minwidth: popup_width,
  maxwidth: popup_width,
  minheight: popup_height,
  maxheight: popup_height,
  borderchars: ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
  border: [1, 1, 1, 1],
  callback: PopupSelectCallback,
  filter: PopupFilter
}

var left_popup = popup_menu(menu_items, opts)

unlet opts.callback
opts.col = popup_width + popup_width / 2 + 2
echom typename(opts)
preview_popup = popup_create(1, opts)


# augroup PopupCursorUpdate
#   autocmd!
#   autocmd CursorMoved * echo line('.', left_popup)
# augroup END

# var num_lines = popup_getoptions(left_popup).minheight
# var preview_content = getbufline(1, 3, 3 + num_lines)
# win_execute(preview_popup, 'buffer 1')

# Set up the CursorMoved autocmd
# SetupCursorMovedAutocmd()
