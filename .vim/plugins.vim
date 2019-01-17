set nocompatible              " be iMproved, required
filetype off                  " required

" set the runtime path to include Vundle and initialize
if has('win32') || has('win64')
  set rtp+=%HOME%\vimfiles\bundle\Vundle.vim
else
  set rtp+=~/.vim/bundle/Vundle.vim
endif
call vundle#begin()

Plugin 'VundleVim/Vundle.vim' " Yes, this is required. Vundle manages itself as a plugin

Plugin 'scrooloose/nerdtree'
Plugin 'othree/html5.vim'
Plugin 'rails.vim'
Plugin 'leafgarland/typescript-vim'
Plugin 'peterhoeg/vim-qml'
Plugin 'mkitt/tabline.vim'
Plugin 'tpope/vim-fugitive'
Plugin 'tpope/vim-rhubarb' " Github specific stuff for fugitive
Plugin 'tpope/vim-commentary'
Plugin 'janko-m/vim-test'

" Experimental plugins
Plugin 'tpope/vim-surround'
Plugin 'itchyny/lightline.vim'
Plugin 'jeetsukumaran/vim-buffergator'
Plugin 'w0rp/ale'
Plugin 'junegunn/fzf.vim'
Plugin 'danilo-augusto/vim-afterglow'

call vundle#end()            " required
filetype plugin indent on    " required
