vim9script noclear

# Lazy plugin to find stuff.
# Maintainer:	Ubaldo Tiberi
# License: Vim-License


if !has('vim9script') ||  v:version < 900
    # Needs Vim version 9.0 and above
    echo "You need at least Vim 9.0"
    finish
endif

if exists('g:vim_lazy_find_loaded')
    finish
endif
g:vim_lazy_find_loaded = true


import autoload "../lib/funcs.vim"

command! LazyFindFile funcs.FindFile()
command! LazyFindBuffer funcs.FindBuffer()
command! LazyFindCmdHistory funcs.FindCmdHistory()
command! LazyFindCmdHistory funcs.FindCmdHistory()
command! LazyFindDir funcs.FindDir()
command! LazyFindRecentFile sfuncs.FindRecentFiles()
