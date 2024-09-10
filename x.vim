vim9script noclear


var value = ''
def PopupInputFilter(id: number, key: string): bool
  # var new_char = getcharstr()
  # value = value .. new_char
  # setbufline(bufnr, 1, value)
  if key == "\<cr>"
    popup_close(id)
    return true
  endif
    return false
enddef

var opts = {
  title: "insert coin",
  line: &lines,
  col: &columns,
  posinvert: false,
  filter: PopupInputFilter,
  borderchars: ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
  border: [1, 1, 1, 1],
}


var buf_input = bufnr('$')

inputdialog('>')
# var winid = popup_create('hello', opts)
# while getcharstr() != "\<cr>"
#   var char = getcharstr()
#   popup_settext(winid, char)
# endwhile
# var bufnr = winbufnr(winid)
