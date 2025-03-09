# vim-poptools

Exploit popups as much as you can!

<p align="center">
<img src="/vim_poptools.gif" width="75%" height="75%">
</p>

<p align="center" style="font-size:38;">
* Vim-poptools *
</p>

Poptools aims to scale your productivity by conveniently using popups for a
multitude of tasks, from finding files and directories, to setting your
favorite colorscheme.
Once a list of results is slammed into a popup menu, you can filter it in an
fuzzy or exact fashion.

Poptools is more essential compared to similar plugins such as [fzf][0],
[fuzzyy][1] or [scope][2] and differently from them, external programs are
called _synchronously_, although things may change in the future. :)

Nevertheless, I personally like the interface and how it displays all the
results at once. Additionally, I find the opportunity of saving the last
search very handy. The configuration is also fairly straightforward.

### Commands

The following is what you can search and show in popups.
The commands are self-explanatory:

```
:PoptoolsFindFile
:PoptoolsFindFileInPath # Takes into account the setting of :h 'path'.
:PoptoolsFindDir
:PoptoolsBuffers
:PoptoolsRecentFiles
:PoptoolsCmdHistory
:PoptoolsKill # When something goes wrong, you can clear all the Poptools popups
:PoptoolsColorscheme # The displayed colors depends on the value of :h 'background'
:PoptoolsGrepInBuffer # Find pattern in the current buffer
:PoptoolsGrep # External grep. Grep command is displayed.
:PoptoolsVimgrep # Vimgrep, show results in the quickfix-list instead of a popup.
:PoptoolsLastSearch # Show the last search results
```

... and if you are curious, the following is how I mapped them in my `.vimrc`:

```
nnoremap <c-p> <cmd>PoptoolsFindFile<cr><cr>
nnoremap <c-p>l <cmd>PoptoolsLastSearch<cr>
nnoremap <c-tab> <cmd>PoptoolsBuffers<cr>
nnoremap <c-p>o <cmd>PoptoolsRecentFiles<cr>
```
## Configuration

If you don't like the default behavior, there is room for some customization.
The process is very easy. All you have to do is to set some entries in
the `g:poptools_config` dictionary.

However, keep in mind that you may also change the plugin behavior by through
Vim the options `:h 'wildignore'`, `:h 'wildoptions'` and `:h 'path'`.

### Preview window

You may not want the preview window in every case. For example, you want it
when you _grep_ but not when you open recent files. If that is the case, do as
it follows

```
g:poptools_config = {}
g:poptools_config['preview_grep'] = true
g:poptools_config['preview_recent_files'] = false,
```

### Syntax highlight in the preview window

Syntax highlight in the preview window can be handy, but it may slow down the
user experience. You can avoid using syntax highlight in the preview window by
setting `g:poptools_config['preview_syntax'] = false`. This is useful in case
you are encountering troubles when using the preview window. The match are
still highlighted.


### To fuzzy or not to fuzzy?

You can filter the results either in a fuzzy or in an exact fashion. You choose
it by setting `g:poptools_config['fuzzy_search']` to `true` or to `false`.

It follows an example of configuration:

```
g:poptools_config = {}
g:poptools_config['preview_syntax'] = false
g:poptools_config['preview_recent_files'] = false
g:poptools_config['fuzzy_search'] = false
```
To see the whole list of keys allowed in the `g:poptools_config` dictionary,
take a look at `:h poptools.txt`.

## Some notes on files/patterns search

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
  cmd_win_default = $'powershell -NoProfile -ExecutionPolicy Bypass -Command "for /R \"{search_dir}\" %f in ({files}) do @findstr /C:\"{what}\" /N \"%f\""' # Not working yet
  cmd_nix_default = $'grep -nrH --include="{files}" "{what}" {search_dir}'
```

where the values of `{what}`,`{files}` and `{search_dir}` are replaced by
user input.

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


[0]: https://github.com/junegunn/fzf.vim
[1]: https://github.com/Donaldttt/fuzzyy
[2]: https://github.com/girishji/scope.vim
