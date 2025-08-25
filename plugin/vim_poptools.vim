vim9script noclear

# Slam stuff in a popup
# Maintainer:	Ubaldo Tiberi
# License: BSD3-Clause
#
# The architecture is fairly easy
#   1. API functions are used to create a "results" var
#   2. Such a "results" variable is placed into a popup
#   3. Depending on the type of search, the way the results are displayed into
#      popups and what the callback function should do may change.

if !has('vim9script') ||  v:version < 900
  # Needs Vim version 9.0 and above
  echo "You need at least Vim 9.0"
  finish
endif

g:loaded_vim_poptools = true

var release_notes =<< END

## Create your dashboard

The command `:PoptoolsIndex` is included to create dashboards.
See `:h PoptoolsIndex` for more info.

Press <Esc> or 'q' to close this popup.
END


def ReleaseNotesFilter(id: number, key: string): bool
  # To handle the keys when release notes popup is visible
  # Close
  if key ==# 'q' || key ==# "\<esc>"
    popup_close(id)
  # Move down
  elseif ["\<tab>", "\<C-n>", "\<Down>", "\<ScrollWheelDown>"]->index(key) != -1
    win_execute(id, "normal! \<c-e>")
  # Move up
  elseif ["\<S-Tab>", "\<C-p>", "\<Up>", "\<ScrollWheelUp>"]->index(key) != -1
    win_execute(id, "normal! \<c-y>")
  # Jump down
  elseif key == "\<C-f>"
    win_execute(id, "normal! \<c-f>")
  # Jump up
  elseif key == "\<C-b>"
    win_execute(id, "normal! \<c-b>")
  else
    return false
  endif
  return true
enddef
def ShowReleaseNotes()
  const title = " vim-poptools "
  const popup_options = {
      border: [1, 1, 1, 1],
      borderchars:  ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
      scrollbar: false,
      title: title,
      filter: ReleaseNotesFilter
    }

  const popup_id = popup_create(release_notes, popup_options)
  win_execute(popup_id, 'set filetype=markdown')
  win_execute(popup_id, 'set conceallevel=2')
enddef


import autoload "../lib/funcs.vim"
import autoload "../lib/indices.vim"

command! -nargs=? PoptoolsIndex indices.ShowIndex(<f-args>)
command! PoptoolsFindFile funcs.FindFile('file')
command! PoptoolsFindFileInPath funcs.FindFile('file_in_path')
command! PoptoolsFindDir funcs.FindDir()
command! PoptoolsBuffers funcs.Buffers()
command! PoptoolsRecentFiles funcs.RecentFiles()
command! PoptoolsCmdHistory funcs.CmdHistory()
command! PoptoolsGrep funcs.Grep()
command! -nargs=? PoptoolsGrepInBuffer funcs.GrepInBuffer(<f-args>)
command! PoptoolsVimgrep funcs.Vimgrep()
command! PoptoolsColorscheme funcs.Colorscheme()
command! PoptoolsLastSearch funcs.LastSearch()
command! PoptoolsKill funcs.ClosePopups()
command! PoptoolsReleaseNotes ShowReleaseNotes()
