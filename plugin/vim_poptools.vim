vim9script noclear

# Slam stuff in a popup
# Maintainer:	Ubaldo Tiberi
# License: Vim-License

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

command! PopupFindFile funcs.FindFileOrDir('file')
command! PopupFindDir funcs.FindFileOrDir('dir')
command! PopupBuffers funcs.Buffers()
command! PopupRecentFiles funcs.RecentFiles()
command! PopupCmdHistory funcs.CmdHistory()
command! PopupGrep funcs.Grep()
