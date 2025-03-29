" Enables "gf / go to file" on *.js file paths
" in typescript projects by routing to the *.ts file instead
set includeexpr=tr(v:fname,'.js','.ts')
