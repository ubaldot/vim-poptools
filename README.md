# vim-poptools

A simple plugin to show stuff in popup menus.

<p align="center">
<img src="/vim_poptools.png" width="75%" height="75%">
</p>

<p align="center" style="font-size:38;">
* Vim-poptools *
</p>

It is not feature rich and performing as other plugins like
[fzf](https://github.com/junegunn/fzf.vim),
[fuzzyy](https://github.com/Donaldttt/fuzzyy) or
[scope](https://github.com/girishji/scope.vim), but it supports my everyday
job pretty well.

Furthermore, I wanted to practice new things that I discovered in Vim such as
the `getcompletion()` function. In-fact, differently than the mentioned
plugins, this plugin is blocking. The others are not.

Therefore, I don't expect that you will use it, but, just in case you want to
try, consider that the commands for finding stuff take into account the
setting of `'wildignore'` option, so if you want to exclude some search path,
you must adjust it.

At the moment the following is what you can show the following in popups. I
guess what the commands do is self-explanatory:

```
:PopupFindFile
:PopupFindDir
:PopupBuffers
:PopupRecentFiles
:PopupCmdHistory
```

... and if you are curious, this is what I have in my `.vimrc`

```
nnoremap <c-p> <cmd>PopupFindFile<cr>
nnoremap <c-tab> <cmd>PopupBuffers<cr>
nnoremap <c-p>h <cmd>PopupCmdHistory<cr>
xnoremap <c-p>h <esc>PopupCmdHistory<cr>
nnoremap <c-p>d <cmd>PopupFindDir<cr>
nnoremap <c-p>o <cmd>PopupRecentFiles<cr>
```
