#!/bin/bash

if [ -z "${HOME}" ]
then
  echo "\$HOME is empty and must be set"
fi

paths_to_link=(
".config"
".gitconfig"
".macos"
".tmux.conf"
".vim"
".zshrc"
"oh-my-posh-themes"
)

for i in "${paths_to_link[@]}"
do
  echo "Linking ${i} to ${HOME}/${i}"
  ln -sf "${PWD}/${i}" "${HOME}/${i}"
done
