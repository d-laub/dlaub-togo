#!/usr/bin/env bash

set -euo pipefail

# install pixi and oh-my-bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)"

# download repo
git clone --branch main https://github.com/d-laub/dlaub-togo.git /tmp/dlaub-togo-tmp

# download and add aliases
cat /tmp/dlaub-togo-tmp/aliases.sh >> ~/.bash_aliases

# set theme
mkdir -p ~/.oh-my-bash/themes
mv -r /tmp/dlaub-togo-tmp/agnoster-multiline ~/.oh-my-bash/themes/
sd '^OSH_THEME=.*$' 'OSH_THEME="agnoster-multiline"' ~/.bashrc

# install global tools
curl -fsSL https://pixi.sh/install.sh | sh
export PATH="${HOME}/.pixi/bin:${PATH}"
pixi g i ripgrep bat glow-md sd zoxide rnr fd-find exa prek git gh less zellij
echo 'eval "$(zoxide init bash)"' >> ~/.bashrc

# config zellij
mkdir -p ~/.config/zellij
mv /tmp/dlaub-togo-tmp/zellij_config.kdl ~/.config/zellij/config.kdl

# clean up
rm -rf /tmp/dlaub-togo-tmp

echo 'Finished setting up shell environment from dlaub-togo, reload with "source ~/.bashrc" for changes to take effect.'

