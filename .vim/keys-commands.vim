imap hh <ESC> " quick shortcut for esc (good for ipad)

" Splits / Grids
nnoremap <C-J> <C-W><C-J>
nnoremap <C-K> <C-W><C-K>
nnoremap <C-L> <C-W><C-L>
nnoremap <C-H> <C-W><C-H>

nnoremap <cr> :nohlsearch<cr> " clear hls on return

" Quickly delete trailing spaces and tab characters turning the tabs into 4 spaces
function! ClearAllTrailingSpaces()
  %s/\s\+$//
endfunction

nmap ,s :call ClearAllTrailingSpaces()<cr>

function! FormatJson()
  %!python3 -m json.tool
endfunction

function! SplitMaster()
  %Gvsplit master:%
endfunction

nmap ,js :call FormatJson()<cr>
nmap ,ss :call SplitMaster()<cr>
nmap ,ff :ALEFix<cr>

command Blame :call gitblame#echo()
