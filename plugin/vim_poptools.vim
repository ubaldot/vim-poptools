vim9script noclear

# Slam stuff in a popup
# Maintainer:	Ubaldo Tiberi
# License: Vim-License
#
# The architecture is quite simple.
#   1. The function called by the command below ask for user input and create a list of strings that are
#      passed to ShowPopup() function which is kind of the main function.
#   2. ShowPopup() create the actual popup_menu and assign:
#
#       a. A Filter function, that is triggered when user press any key on the
#       keyboard
#       b. A Callback function, that is triggered when user press <cr>
#
#     depending on the user selection.
#

if !has('vim9script') ||  v:version < 900
    # Needs Vim version 9.0 and above
    echo "You need at least Vim 9.0"
    finish
endif

if exists('g:vim_poptools_loaded')
    finish
endif
g:vim_poptools_loaded = true

import autoload "../lib/funcs.vim"

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
