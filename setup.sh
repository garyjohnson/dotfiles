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
)

for i in "${paths_to_link[@]}"
  ln -s "${PWD}/${i}" "${HOME}/${i}"
do
done
