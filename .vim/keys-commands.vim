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

function! FormatJson()
  %!python3 -m json.tool
endfunction

function! SplitMain()
  %Gvsplit main:%
endfunction

" scratch pad buffer                                                                                                                                                                  
" modified from https://vi.stackexchange.com/a/21390 by Kat Tipton                                                                                                                                  
function! Scratch()                                                                                                                                                                   
  if bufnr("scratch") > 0                                                                                                                                                             
    sbuffer scratch                                                                                                                                                                   
  else                                                                                                                                                                                
    split                                                                                                                                                                             
    noswapfile hide enew                                                                                                                                                              
    setlocal buftype=nofile                                                                                                                                                           
    setlocal bufhidden=hide                                                                                                                                                           
    "setlocal nobuflisted                                                                                                                                                             
    "lcd ~                                                                                                                                                                            
    file scratch                                                                                                                                                                      
  endif                                                                                                                                                                               
endfunction       

" create a scratch window or open an existing one
nnoremap <C-s> :call Scratch()<CR>

nmap ,s :call ClearAllTrailingSpaces()<cr>
nmap ,js :call FormatJson()<cr>
nmap ,ss :call SplitMain()<cr>

" buffer stuff
map ,jj :bnext<CR>
map ,kk :bprev<CR>
"
" from https://www.reddit.com/r/vim/comments/g4l5p0/good_plugin_to_navigate_buffers/
" type the buffer number + <CR> right afterwards to go to the buffer you want
nnoremap <leader>b :ls<CR>:b
