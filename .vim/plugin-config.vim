" airline
" -------
let g:airline#extensions#tabline#enabled = 1

" go-vim
" -------
" let g:go_metalinter_autosave = 1
" let g:go_metalinter_autosave_enabled = ['vet', 'golint', 'errcheck']

" golenview
" --------
let g:goldenview__enable_default_mapping = 0 " default keys overlap nerdtree binding 

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
nmap ,t :TestNearest<CR>
nmap ,T :TestFile<CR>

" build button
nmap <silent> <M-6> :TestNearest<CR> 
nmap <silent> <M-7> :TestFile<CR>
nmap <silent> <M-8> :TestSuite<CR>

" ale
" --------
nmap ,k :ALENext<cr>
nmap ,j :ALEPrevious<cr>
nmap ,fx :ALEFix<CR>
nmap ,gd :ALEGoToDefinition<CR>
nmap ,fr :ALEFindReferences<CR>

let g:ale_completion_enabled = 1

let g:ale_linters = {
\   'ruby': ['standardrb', 'solargraph'],
\   'graphql': ['graphql-schema-linter'],
\   'js': ['eslint'],
\   'jsx': ['eslint'],
\   'typescript': ['eslint', 'tsserver'],
\   'typescriptreact': ['eslint', 'tsserver'],
\}
let g:ale_fixers = {
\   '*': ['remove_trailing_lines', 'trim_whitespace'],
\   'ruby': ['standardrb'],
\   'javascript': ['prettier', 'eslint'],
\   'typescript': ['prettier', 'eslint'],
\   'typescriptreact': ['prettier', 'eslint'],
\   'scss': ['stylelint'],
\}

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
"let g:fzf_layout = { 'down': '~40%' }

" In Neovim, you can set up fzf window using a Vim command
let g:fzf_layout = { 'window': { 'width': 0.9, 'height': 0.6 } }

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
nnoremap <silent> <expr> <C-g> (expand('%') =~ 'NERD_tree' ? "\<c-w>\<c-w>" : '').":Rg\<cr>"

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
