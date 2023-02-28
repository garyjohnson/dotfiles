function Cheat()
  echo " \"*y         | Yank into clipboard"
  echo " C-p          | Find file name (fzf.vim)"
  echo " C-n          | Open nerdtree (nerdtree)"
  echo " ,n           | Select the open file in nerdtree (nerdtree)"
  echo " m            | Operate on highlighted file or directory in nerdtree (nerdtree)"
  echo " ,kk | ,jj    | Go to next / previous buffer (/keys-commands.vim)"
  echo " ,b           | View list of buffers (/keys-commands.vim)"
  echo " :GBlame      | Show git blame (fugitive)"
  echo " :Git Browse  | Open highlighted lines or file in GitHub (fugitive)"
  echo " gc | gcc     | Comment line in visual mode / or with count (commentary)"
  echo " ,ss          | Open split diff with main branch (/keys-commands.vim)"
  echo " ,js          | Format json file (/keys-commands.vim)"
  echo " ,s           | Clear all trailing spaces (/keys-commands.vim)"
  echo " ,fx          | Format (coc.nvim)"
  echo " cst{replace} | Replace surrounding tags (vim-surround)"
  echo " ---------------------------------------------------------------------"
  echo " s   | i      | Open splits from nerdtree pane"
endfunction

command Cheat :call Cheat()
