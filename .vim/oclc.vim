if has("autocmd")
  autocmd FileType javascript setlocal expandtab shiftwidth=4 softtabstop=4
  autocmd FileType javascriptreact setlocal expandtab shiftwidth=4 softtabstop=4
  autocmd FileType typescript setlocal expandtab shiftwidth=4 softtabstop=4
  autocmd FileType typescriptreact setlocal expandtab shiftwidth=4 softtabstop=4
endif

let g:fubitive_domain_pattern = 'git\.ent\.oclc\.org'
let g:fubitive_default_protocol = 'http://'

map ,ls :0read ~/.vim/licenses/oclc.txt<CR>
command TReact :0read ~/.vim/templates/oclc/react-component.tsx
command TReactTest :0read ~/.vim/templates/oclc/react-component-test.ts
command TStory :0read ~/.vim/templates/oclc/storybook-story.tsx
command TTest :0read ~/.vim/templates/oclc/jest-test.ts
