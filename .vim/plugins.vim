set nocompatible              " be iMproved, required
filetype off                  " required

if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

call plug#begin('~/.vim/plugged')

Plug 'scrooloose/nerdtree' " file browser

Plug 'tpope/vim-fugitive' " Git commands
Plug 'tpope/vim-rhubarb' " Github specific stuff for fugitive

Plug 'tpope/vim-commentary' " comment commands
Plug 'vim-test/vim-test' "test commands
Plug 'itchyny/lightline.vim' " status line
Plug 'danilo-augusto/vim-afterglow' " color theme
Plug 'tpope/vim-surround' " shortcuts for surrounds
Plug 'zhaocai/GoldenView.Vim' " manages split sizes

" Plug 'mkitt/tabline.vim' " archived
" Plug 'w0rp/ale'
" Plug 'jeetsukumaran/vim-buffergator'
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
Plug 'neoclide/coc.nvim', {'branch': 'release'}

" Plug 'kchmck/vim-coffee-script'
" Plug 'slim-template/vim-slim'
" Plug 'davisdude/vim-love-docs'
" Plug 'othree/html5.vim'
" Plug 'leafgarland/typescript-vim'
" Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries' }

call plug#end()
filetype plugin indent on    " required
