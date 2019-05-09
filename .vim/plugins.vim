set nocompatible              " be iMproved, required
filetype off                  " required

if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

call plug#begin('~/.vim/plugged')

Plug 'scrooloose/nerdtree'
Plug 'othree/html5.vim'
Plug 'vim-scripts/rails.vim'
Plug 'leafgarland/typescript-vim'
Plug 'peterhoeg/vim-qml'
Plug 'mkitt/tabline.vim'
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-rhubarb' " Github specific stuff for fugitive
Plug 'tpope/vim-commentary'
Plug 'janko-m/vim-test'
Plug 'w0rp/ale'
Plug 'itchyny/lightline.vim'
Plug 'danilo-augusto/vim-afterglow'
Plug 'kchmck/vim-coffee-script'
Plug 'tpope/vim-surround'
Plug 'jeetsukumaran/vim-buffergator'
Plug 'junegunn/fzf.vim'
Plug 'zhaocai/GoldenView.Vim'

" Experimental plugins
Plug 'neoclide/coc.nvim', {'tag': '*', 'do': './install.sh'}

call plug#end()
filetype plugin indent on    " required
