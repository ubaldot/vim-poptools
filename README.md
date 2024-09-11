# vim-poptools

Exploit popups as much as you can!

<p align="center">
<img src="/vim_poptools.gif" width="75%" height="75%">
</p>

<p align="center" style="font-size:38;">
* Vim-poptools *
</p>

This plugin aims to scale your productivity by conveniently using popups for a
multitude of tasks, from finding files and directories, to setting your
favorite colorscheme.

It is more essential compared to similar plugins such as [fzf][0], [fuzzyy][1]
or [scope][2]. Under some circumstances it may be slower, but I don't mind
waiting a bit when the search process takes a while; it helps me pause and
reflect on what I am doing, giving my brain some breathing room.

Nevertheless, I personally like the interface and how it displays all the
results at once. Additionally, I find the opportunity of saving the last
search very handy. The configuration is also fairly straightforward.

### Commands

At the moment the following is what you can search and show in popups. I guess
the commands are self-explanatory:

```
:PoptoolsFindFile
:PoptoolsFindFileInPath # Takes into account the setting of :h 'path'.
:PoptoolsFindDir
:PoptoolsBuffers
:PoptoolsRecentFiles
:PoptoolsCmdHistory
:PoptoolsColorscheme # The displayed colors depends on the value of :h 'background'
:PoptoolsGrep # External grep. Grep command is displayed.
:PoptoolsVimgrep # Vimgrep, show results in the quickfix-list instead of a popup.
:PoptoolsLastSearch # Show the last search results
```

... and if you are curious, the following is how I mapped them in my `.vimrc`:

```
nnoremap <c-p> <cmd>PoptoolsFindFile<cr><cr>
nnoremap <c-p>f <cmd>PoptoolsFindFile<cr>
nnoremap <c-p>l <cmd>PoptoolsLastSearch<cr>
nnoremap <c-tab> <cmd>PoptoolsBuffers<cr>
nnoremap <c-p>h <cmd>PoptoolsCmdHistory<cr>
xnoremap <c-p>h <esc>PoptoolsCmdHistory<cr>
nnoremap <c-p>d <cmd>PoptoolsFindDir<cr>
nnoremap <c-p>o <cmd>PoptoolsRecentFiles<cr>
nnoremap <c-p>g <cmd>PoptoolsGrep<cr>
```

## File search

`PoptoolsFindFile` and `PoptoolsFindInPath`

These commands take into account the setting of `:h 'wildignore'`,
`:h 'wildoptions'` and `:h 'path'` options, so if you want to include/exclude
some search path, you must adjust such options.

By default, hidden files are excluded. If you want to find them, then you must
add `.` at the beginning of the search pattern, e.g. use `.git*` to get e.g.
`.gitignore`.

Hidden files are searched in non-hidden folders. To find files in a hidden
folder, you must first `cd` into such a folder. For example, `cd ~/.vim`
followed by `PopupFindFiles` will search files inside the `.vim` folder.

`PoptoolsGrep`

This command uses an external "grep" program and therefore it is not affected
by the Vim options settings. The default "grep" commands are the following:

<!-- cmd_win_default = $'cmd.exe /c cd {shellescape(getcwd())} && findstr /C:{shellescape(what)} /N /S {files} | findstr /V /R "^\..*\\\\"' -->

```
  cmd_win_default = $'powershell -NoProfile -ExecutionPolicy Bypass -Command "cd {getcwd()};findstr /C:{shellescape(what)} /N /S {files}"'
  cmd_nix_default = $'grep -n -r --include="{files}" "{what}" {getcwd()}'
```

where the values of `{what}` and `{files}` are replaced by user input.

<!-- You can override them by setting `g:poptools_config['cmd_win']` and -->
<!-- `g:poptools_config['cmd_nix']`, respectively. -->

<!-- In such an overriding, you can use the `{what}`, `{files}`, and `{search_dir}` -->
<!-- placeholders to specify the string to search (e.g. `foo`), the files pattern -->
<!-- (e.g. `*.vim`) and the search folder (e.g. `~/myproject`), respectively. The -->
<!-- values that you will be prompted to insert will be placed into those -->
<!-- placeholders. -->

### Folder search

To find hidden folders with `PopupFindDir` command, just add a `.` in front of
the search pattern, e.g. `.git*`. That will return e.g. `.git/, .github/`,
etc.

## Configuration

If you don't like the default behavior, there is room for some customization.
You can do it through Vim the options `:h 'wildignore'`, `:h 'wildoptions'`
and `:h 'path'` and/or through the `g:poptools_config` dictionary that you can
set as it follows.

To do that, be sure to create an empty dictionary in your `.vimrc` file, i.e.
`g:poptools_config = {}`.

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

Syntax highlight in the preview can be handy, but it may slow down the user
experience. You can avoid using syntax highlight in the preview window by
setting `g:poptools_config['preview_syntax'] = false`. This is useful in case
you are encountering troubles when using the preview window. The match are
still highlighted.

All the boolean values in the `g:poptools_config` are set to `true` as
default.

It follows an example of configuration:

```
g:poptools_config = {}`
g:poptools_config['preview_syntax'] = false
g:poptools_config['preview_recent_files'] = false
```

[0]: https://github.com/junegunn/fzf.vim
[1]: https://github.com/Donaldttt/fuzzyy
[2]: https://github.com/girishji/scope.vim
