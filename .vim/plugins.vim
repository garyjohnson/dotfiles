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

Plug 'tpope/vim-rails' " better file navigation in rails projects
Plug 'tpope/vim-commentary' " comment commands
Plug 'vim-test/vim-test' "test commands
Plug 'itchyny/lightline.vim' " status line
Plug 'danilo-augusto/vim-afterglow' " color theme
Plug 'tpope/vim-surround' " shortcuts for surrounds
Plug 'zhaocai/GoldenView.Vim' " manages split sizes

Plug 'junegunn/fzf', { 'do': { -> fzf#install() } } " file searching
Plug 'junegunn/fzf.vim'
Plug 'dense-analysis/ale' " linting & fixing

call plug#end()
filetype plugin indent on    " required
