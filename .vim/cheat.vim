function Cheat()
  echo " C-^       | Open previous file"
  echo " C-p       | Find file name (ctrlp.vim)"
  echo " C-n       | Open nerdtree (nerdtree)"
  echo " ,n        | Select the open file in nerdtree (nerdtree)"
  echo " ,s        | Clear all trailing spaces (vimrc/ClearAllTrailingSpaces())"
  echo " m         | Operate on highlighted file or directory in nerdtree (nerdtree)"
  echo " :tabnew   | Create new tab"
  echo " gn | gp   | Go to next tab"
  echo " ,kk | ,jj | Go to next / previous buffer (Buffergator)"
  echo " ,bl       | View list of buffers (Buffergator)"
  echo " :Gblame   | Show git blame (fugitive)"
  echo " :Gbrowse  | Open highlighted lines or file in GitHub (fugitive)"
  echo " gc | gcc  | Comment line in visual mode / or with count (commentary)"
  echo " ---------------------------------------------------------------------"
  echo " C-v | C-s | Open splits from ctrlp pane"
  echo " s   | i   | Open splits from nerdtree pane"
endfunction

command Cheat :call Cheat()
