function! RunTests(filename)
" Write the file and run tests for the given filename
    :w
    :silent !echo;echo;echo;echo;echo
    exec ":!bundle exec rspec " . a:filename
endfunction

function! SetTestFile()
" Set the spec file that tests will be run for.
  let t:grb_test_file=@%
endfunction

function! SetTestLine(line)
  let t:grb_test_line=a:line
endfunction

function! RunTestFile(...)
  let in_spec_file = match(expand("%"), '_spec.rb$') != -1
  if a:0
    if in_spec_file
      call SetTestLine(a:1)
    endif
    if exists("t:grb_test_line")
      let command_suffix = t:grb_test_line
    else
      let command_suffix = ""
    endif
  else
    let command_suffix = ""
  endif
" Run the tests for the previously-marked file.
  if in_spec_file
    call SetTestFile()
  elseif !exists("t:grb_test_file")
    return
  end
  call RunTests(t:grb_test_file . command_suffix)
endfunction

function! RunNearestTest()
  let spec_line_number = line('.')
  call RunTestFile(":" . spec_line_number)
endfunction

function! SetFeatureFile()
  let t:grb_feature_file=@%
endfunction

function! RunFeatureTest()
  let in_feature_file = match(expand("%"), '.feature$') != -1
" Run the tests for the previously-marked file.
  if in_feature_file
    call SetFeatureFile()
  elseif !exists("t:grb_feature_file")
    return
  end

  :w
  :silent !echo;echo;echo;echo;echo
  exec ":!cucumber " . t:grb_feature_file
endfunction

" Run this file
" map <leader>t :call RunTestFile()<cr>
" Run only the example under the cursor
" map <leader>T :call RunNearestTest()<cr>
" Run cucumber wip
" map <leader>f :w\|:!cucumber -p wip<cr>
map ,t :call RunTestFile()<cr>
map ,T :call RunNearestTest()<cr>
map ,w :w\|:!cucumber -p wip<cr>
map ,f :call RunFeatureTest()<cr>
