#!/bin/bash

if [ -z "${HOME}" ]
then
  echo "\$HOME is empty and must be set"
fi

paths_to_link=(
".config/lvim"
".config/nvim"
".profile"
".gitconfig"
".macos"
".tmux.conf"
".vim"
".zshrc"
"oh-my-posh-themes"
)

for i in "${paths_to_link[@]}"
do
  SOURCE="${PWD}/${i}"
  DESTINATION="${HOME}/${i}"
  DESTINATION_PATH=$(echo "${DESTINATION}" | sed -e "s/\/[^\/]*$//")
  echo "Linking ${SOURCE} to ${DESTINATION_PATH}"
  ln -sfi "${SOURCE}" "${DESTINATION_PATH}"
done

echo "Don't forget to run 'brew bundle' as non-root!"
