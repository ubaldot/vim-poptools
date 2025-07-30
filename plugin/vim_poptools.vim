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

if exists('g:vim_poptools_loaded')
  finish
endif
g:vim_poptools_loaded = true

var release_notes =<< END
# vim-poptools: release notes

## Links



Press <Esc> to close this popup.
END

def ShowReleaseNotes()

  const popup_options = {
      border: [1, 1, 1, 1],
      borderchars:  ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
      filter: 'popup_filter_menu',
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
