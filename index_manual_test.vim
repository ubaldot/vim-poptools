vim9script

message clear

def Bar()
  echom "Fatto!"
enddef

def g:Foo()
  echom "Fatto!"
enddef

var test = [
  ["file", 'C:\Users\yt75534\vimfiles\plugins\vim-markdown-extras\testfile.md'],
  ["link", 'https://example.com'],
  ["func", "function('g:Foo')"],
  ["empty", ""],
  # ["wrong_type", 12234],
  ["func_lambda", string(() => 'echo "ECCOLA!"')],
  ["non_global_func", "function('Bar')"],
]

var test_safe = [
  ["file", 'C:\Users\yt75534\vimfiles\plugins\vim-markdown-extras\testfile.md'],
  ["link", 'https://example.com'],
  ["global_func", "function('g:Foo')"],
]
execute  $"PoptoolsIndex {test}"
