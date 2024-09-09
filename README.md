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
job pretty well. I personally like how it displays information. :)

The motivation of this plugin is that I wanted to practice new things that I
discovered in Vim such as the `getcompletion()` function. In-fact, differently
than the mentioned plugins, this is synchronous. The others are not.
Nevertheless, I don't mind to wait a bit while the search process is on-going:
it helps me in pausing and reflecting on what I am doing.

Therefore, I don't expect that you will use it, but, just in case you want to
give it a try, consider that the commands for finding stuff take into account
the setting of `'wildignore'` and `'wildoptions'` options, so if you want to
exclude some search path, you must adjust these options.

### Commands

At the moment the following is what you can show in popups. I guess what the
commands do is self-explanatory:

```
:PopupFindFile
:PopupFindFileInPath # Takes into account the setting of `:h 'path'`.
:PopupFindDir
:PopupBuffers
:PopupRecentFiles
:PopupCmdHistory
:PopupColorscheme
:PopupGrep # External grep, show results in a popup. Grep command is displayed.
:PopupVimgrep # Vimgrep, show results in the quickfix-list.
```

... and if you are curious, this is what I have in my `.vimrc`

```
nnoremap <c-p> <cmd>PopupFindFile<cr><cr>
nnoremap <c-p>f <cmd>PopupFindFile<cr>
nnoremap <c-tab> <cmd>PopupBuffers<cr>
nnoremap <c-p>h <cmd>PopupCmdHistory<cr>
xnoremap <c-p>h <esc>PopupCmdHistory<cr>
nnoremap <c-p>d <cmd>PopupFindDir<cr>
nnoremap <c-p>o <cmd>PopupRecentFiles<cr>
nnoremap <c-p>g <cmd>PopupGrep<cr>
```

## Few notes

### File search

By default, hidden files are excluded. If you want to find a hidden file, then
you must add `.` at the beginning of the search pattern of `PopupFindFile`,
e.g. `.git*` or just `.`. Note that hidden files are searched in non-hidden
folders. To find files in a hidden folder, you must first `cd` into such a
folder. For example, `cd ~/.vim` followed by `PopupFindFiles` will search
files inside the `.vim` folder.

### Folder search

To find hidden folders with `PopupFindDir` command, just add a `.` in front of
the search pattern, e.g. `.git*`.

## Configuration

If you don't like the defaults, you can customize vim-poptools either through
the options `'wildignoe'` and `'path'` and/or through the `g:poptools_config`
dictionary that you can set as it follows. But first or all, be sure to create
an empty dictionary in your `.vimrc` file, i.e. `g:poptools_config = {}`.

### grep command

The default "grep" commands are:

```
  cmd_win_default = $'powershell -command "Set-Location -Path {cwd};gci -Recurse -Filter {files} | Select-String -Pattern {what} -CaseSensitive"'
  cmd_nix_default = $'grep -n -r --include="{files}" "{what}" {cwd}'
```

but you can override them by setting `g:poptools_config['cmd_win']` and
`g:poptools_config['cmd_nix']`, respectively. You are free to use the
placeholders _what_, _files_, and _search_dir_ to specify the string to search
(e.g. `foo`), the files pattern (e.g. `*.vim`) and the search folder (e.g.
`~/myproject`), respectively

The default "grep" commands are:

```
  cmd_win_default = $'powershell -command "Set-Location -Path {search_dir};gci -Recurse -Filter {files} | Select-String -Pattern {what} -CaseSensitive"'
  cmd_nix_default = $'grep -n -r --include="{files}" "{what}" {search_dir}'
```

### Preview window

You may not want the preview window in every case. For example, you want it
when you _grep_ but not when you open recent files. You can specify when you
want the following keys:

```
 'preview_file',
 'preview_file_in_path',
 'preview_recent_files',
 'preview_buffer',
 'preview_grep'.
```

You can for example specify
`g:poptools_config['preview_grep'] = true, g:poptools_config['preview_recent_files'] = false,`
to have a preview window in your grep result list, but not in the recent files
list.
