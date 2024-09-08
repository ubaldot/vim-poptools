vim9script

# --- NOT USED but useful
def GetFiletypeByFilename(fname: string): string
    # NOT USED
    # Pretend to load a buffer and detect its filetype manually
    # Used in UpdatePreviewAlternative()

    # just return &filetype if buffer was already loaded
    if bufloaded(fname)
        return getbufvar(fname, '&filetype')
    endif

    new
    try
        # the `file' command never reads file data from disk
        # (but may read path/directory contents)
        # however the detection will become less accurate
        # as some types cannot be recognized for empty files
        noautocmd silent! execute 'file' fnameescape(fname)
        filetype detect
        return &filetype
    finally
        bwipeout!
    endtry
    return ''
enddef

def UpdatePreviewAlternative(main_id: number, preview_id: number, search_type: string)
  # NOT USED
  # Alternative way for setting the filetype in the preview window.
  # It works with GetFiletypeByFilename() and it is slower
  var idx = line('.', main_id)
  var highlighted_line = getbufline(winbufnr(main_id), idx)[0]
  var buf_lines = readfile(expand(highlighted_line), '', popup_height)

  # UBA SPERMA
  var buf_filetype = GetFiletypeByFilename(highlighted_line)

  # Clean the preview
  popup_settext(preview_id, repeat([""], popup_height))
  # populate the preview
  # TODO readfile gives me folded content
  popup_settext(preview_id, buf_lines)
  # Syntax highlight
  win_execute(preview_id, $'&filetype = "{buf_filetype}"')

  # Set preview ID title
  var preview_id_opts = popup_getoptions(preview_id)
  preview_id_opts.title = $' {highlighted_line} '
  popup_setoptions(preview_id, preview_id_opts)
enddef
# ------------ END NOT USED -----------
