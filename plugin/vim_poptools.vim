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
