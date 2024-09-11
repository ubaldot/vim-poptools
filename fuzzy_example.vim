vim9script

# Copied from Vim github repo in Issues/Closed.

# With fuzzy search, you first get a list of everything, and then you start to
# filter in real-time
# Wit classic search you type what you want and then you get the results.

def Callback(winid: number, choice: number)
  if choice == -1
    return
  endif
  execute $'split {winid->winbufnr()->getbufline(1, '$')->get(choice - 1, '')}'
enddef

var win: number = v:oldfiles->popup_create({
  border: [],
  callback: Callback,
  cursorline: true,
  minheight: 10, maxheight: 10,
  minwidth: 80, maxwidth: 80,
  scrollbar: false,
})
redraw

augroup FuzzyOldfiles | autocmd!
  autocmd CmdlineChanged @ MatchFuzzy(win)
  autocmd CmdlineLeave @ TearDown()
augroup END

prop_type_add('FuzzyOldfiles', {bufnr: win->winbufnr(), highlight: 'WarningMsg'})
def MatchFuzzy(winid: number)
  var look_for: string = getcmdline()
  if look_for == ''
    popup_settext(winid, v:oldfiles) | redraw
    return
  endif
  var matches: list<list<any>> = v:oldfiles->matchfuzzypos(look_for)
  var pos: list<list<number>> = matches->get(1, [])
  var text: list<dict<any>> = matches->get(0, [])
    ->map((i: number, match: string) => ({
      text: match,
      props: pos[i]->copy()->map((_, col: number) => ({
        col: col + 1,
        length: 1,
        type: 'FuzzyOldfiles'
    }))}))
  popup_settext(winid, text) | redraw
  win_execute(winid, 'normal! 1Gzt')
enddef

cnoremap <buffer><nowait> <Down> <ScriptCmd>popup_filter_menu(win, 'j')<Bar>redraw<CR>
cnoremap <buffer><nowait> <Up> <ScriptCmd>popup_filter_menu(win, 'k')<Bar>redraw<CR>
def TearDown()
  autocmd! FuzzyOldfiles
  augroup! FuzzyOldfiles
  cunmap <buffer> <Down>
  cunmap <buffer> <Up>
enddef

input('look for: ') | echo ''
popup_filter_menu(win, "\<CR>")
