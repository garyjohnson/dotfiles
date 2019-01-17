" nerdtree
" --------
nmap ,n :NERDTreeFind<CR>
map <C-n> :NERDTreeToggle<CR>

" theme
" --------
set termguicolors
set background = "dark"
let g:afterglow_blackout=0
colorscheme afterglow

" lightline
" --------
set noshowmode " don't show mode in own line -- insert, et al are shown in lightline already

" vim-test
" --------
" vim-test recommended
nmap <silent> ,<C-n> :TestNearest<CR>
nmap <silent> ,<C-f> :TestFile<CR>
nmap <silent> ,<C-s> :TestSuite<CR>
nmap <silent> ,<C-l> :TestLast<CR>
nmap <silent> ,<C-g> :TestVisit<CR>
" vim-test custom
nmap <silent> ,t :TestNearest<CR>
nmap <silent> ,T :TestFile<CR>

" Buffergator
" --------
" show buffer filenames across top
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#fnamemod = ':t'
" Go to the previous buffer open
nmap ,jj :BuffergatorMruCyclePrev<cr>
" Go to the next buffer open
nmap ,kk :BuffergatorMruCycleNext<cr>
" View the entire list of buffers open
nmap ,bl :BuffergatorOpen<cr>

" Ctrlp
" --------
let g:ctrlp_custom_ignore = {
    \ 'dir':  '\.git$\|\.hg$\|\.svn$\|bower_components$\|dist$\|node_modules$\|project_files$\|plugins$\|tmp$\|log$\|doc$',
    \ 'file': '\.exe$\|\.so$\|\.dll$\|\.pyc$\|.DS_Store$' }

" ale
" --------
nmap ,k :ALENext<cr>
nmap ,j :ALEPrevious<cr>

" fzf
" --------
set rtp+=/usr/local/opt/fzf

" This is the default extra key bindings
let g:fzf_action = {
  \ 'ctrl-t': 'tab split',
  \ 'ctrl-x': 'split',
  \ 'ctrl-v': 'vsplit' }

" Default fzf layout
" - down / up / left / right
let g:fzf_layout = { 'down': '~40%' }

" In Neovim, you can set up fzf window using a Vim command
let g:fzf_layout = { 'window': 'enew' }
let g:fzf_layout = { 'window': '-tabnew' }
let g:fzf_layout = { 'window': '10split enew' }

" Customize fzf colors to match your color scheme
let g:fzf_colors =
\ { 'fg':      ['fg', 'Normal'],
  \ 'bg':      ['bg', 'Normal'],
  \ 'hl':      ['fg', 'Comment'],
  \ 'fg+':     ['fg', 'CursorLine', 'CursorColumn', 'Normal'],
  \ 'bg+':     ['bg', 'CursorLine', 'CursorColumn'],
  \ 'hl+':     ['fg', 'Statement'],
  \ 'info':    ['fg', 'PreProc'],
  \ 'border':  ['fg', 'Ignore'],
  \ 'prompt':  ['fg', 'Conditional'],
  \ 'pointer': ['fg', 'Exception'],
  \ 'marker':  ['fg', 'Keyword'],
  \ 'spinner': ['fg', 'Label'],
  \ 'header':  ['fg', 'Comment'] }

" Enable per-command history.
" CTRL-N and CTRL-P will be automatically bound to next-history and
" previous-history instead of down and up. If you don't like the change,
" explicitly bind the keys to down and up in your $FZF_DEFAULT_OPTS.
let g:fzf_history_dir = '~/.local/share/fzf-history'

nnoremap <silent> <expr> <C-p> (expand('%') =~ 'NERD_tree' ? "\<c-w>\<c-w>" : '').":Files\<cr>"

" Mapping selecting mappings
nmap <leader><tab> <plug>(fzf-maps-n)
xmap <leader><tab> <plug>(fzf-maps-x)
omap <leader><tab> <plug>(fzf-maps-o)

" Insert mode completion
imap <c-x><c-k> <plug>(fzf-complete-word)
imap <c-x><c-f> <plug>(fzf-complete-path)
imap <c-x><c-j> <plug>(fzf-complete-file-ag)
imap <c-x><c-l> <plug>(fzf-complete-line)

" Advanced customization using autoload functions
inoremap <expr> <c-x><c-k> fzf#vim#complete#word({'left': '15%'})


