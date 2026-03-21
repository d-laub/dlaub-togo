#!/usr/bin/env bash

set -euo pipefail

# install global tools
curl -fsSL https://pixi.sh/install.sh | sh
export PATH="${HOME}/.pixi/bin:${PATH}"
pixi g i ripgrep bat glow-md sd zoxide rnr fd-find exa prek git gh less zellij
echo 'eval "$(zoxide init bash)"' >> ~/.bashrc

# install oh-my-bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)"

# download and add aliases
cat aliases.sh >> ~/.bash_aliases

# set theme
mkdir -p ~/.oh-my-bash/themes
cp -r agnoster-multiline ~/.oh-my-bash/themes/
sd '^OSH_THEME=.*$' 'OSH_THEME="agnoster-multiline"' ~/.bashrc

# config zellij
mkdir -p ~/.config/zellij
cp zellij_config.kdl ~/.config/zellij/config.kdl

echo 'Finished setting up shell environment from dlaub-togo, reload with "source ~/.bashrc" for changes to take effect.'
