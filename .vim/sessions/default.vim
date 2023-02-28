let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
silent only
silent tabonly
cd ~/repositories/next-blog
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
if &shortmess =~ 'A'
  set shortmess=aoOA
else
  set shortmess=aoO
endif
badd +1 pages/posts/\[slug].tsx
badd +0 styles/Home.module.css
badd +10 styles/Post.module.css
badd +21 components/ProjectTile/ProjectTile.module.css
badd +27 components/ProjectTile/index.tsx
argglobal
%argdel
edit components/ProjectTile/ProjectTile.module.css
let s:save_splitbelow = &splitbelow
let s:save_splitright = &splitright
set splitbelow splitright
wincmd _ | wincmd |
vsplit
wincmd _ | wincmd |
vsplit
wincmd _ | wincmd |
vsplit
3wincmd h
wincmd w
wincmd w
wincmd w
let &splitbelow = s:save_splitbelow
let &splitright = s:save_splitright
wincmd t
let s:save_winminheight = &winminheight
let s:save_winminwidth = &winminwidth
set winminheight=0
set winheight=1
set winminwidth=0
set winwidth=1
exe 'vert 1resize ' . ((&columns * 25 + 89) / 178)
exe 'vert 2resize ' . ((&columns * 106 + 89) / 178)
exe 'vert 3resize ' . ((&columns * 22 + 89) / 178)
exe 'vert 4resize ' . ((&columns * 22 + 89) / 178)
argglobal
enew
file NERD_tree_1
balt pages/posts/\[slug].tsx
setlocal fdm=manual
setlocal fde=0
setlocal fmr={{{,}}}
setlocal fdi=#
setlocal fdl=0
setlocal fml=1
setlocal fdn=20
setlocal nofen
wincmd w
argglobal
balt pages/posts/\[slug].tsx
setlocal fdm=manual
setlocal fde=0
setlocal fmr={{{,}}}
setlocal fdi=#
setlocal fdl=0
setlocal fml=1
setlocal fdn=20
setlocal fen
silent! normal! zE
let &fdl = &fdl
let s:l = 17 - ((16 * winheight(0) + 20) / 41)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 17
normal! 0
wincmd w
argglobal
if bufexists(fnamemodify("components/ProjectTile/index.tsx", ":p")) | buffer components/ProjectTile/index.tsx | else | edit components/ProjectTile/index.tsx | endif
if &buftype ==# 'terminal'
  silent file components/ProjectTile/index.tsx
endif
balt components/ProjectTile/ProjectTile.module.css
setlocal fdm=manual
setlocal fde=0
setlocal fmr={{{,}}}
setlocal fdi=#
setlocal fdl=0
setlocal fml=1
setlocal fdn=20
setlocal fen
silent! normal! zE
let &fdl = &fdl
let s:l = 19 - ((18 * winheight(0) + 20) / 41)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 19
normal! 049|
wincmd w
argglobal
if bufexists(fnamemodify("styles/Post.module.css", ":p")) | buffer styles/Post.module.css | else | edit styles/Post.module.css | endif
if &buftype ==# 'terminal'
  silent file styles/Post.module.css
endif
balt pages/posts/\[slug].tsx
setlocal fdm=manual
setlocal fde=0
setlocal fmr={{{,}}}
setlocal fdi=#
setlocal fdl=0
setlocal fml=1
setlocal fdn=20
setlocal fen
silent! normal! zE
let &fdl = &fdl
let s:l = 8 - ((7 * winheight(0) + 20) / 41)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 8
normal! 019|
wincmd w
2wincmd w
exe 'vert 1resize ' . ((&columns * 25 + 89) / 178)
exe 'vert 2resize ' . ((&columns * 106 + 89) / 178)
exe 'vert 3resize ' . ((&columns * 22 + 89) / 178)
exe 'vert 4resize ' . ((&columns * 22 + 89) / 178)
tabnext 1
if exists('s:wipebuf') && len(win_findbuf(s:wipebuf)) == 0 && getbufvar(s:wipebuf, '&buftype') isnot# 'terminal'
  silent exe 'bwipe ' . s:wipebuf
endif
unlet! s:wipebuf
set winheight=3 winwidth=22
let &shortmess = s:shortmess_save
let &winminheight = s:save_winminheight
let &winminwidth = s:save_winminwidth
let s:sx = expand("<sfile>:p:r")."x.vim"
if filereadable(s:sx)
  exe "source " . fnameescape(s:sx)
endif
let &g:so = s:so_save | let &g:siso = s:siso_save
set hlsearch
nohlsearch
doautoall SessionLoadPost
unlet SessionLoad
" vim: set ft=vim :
