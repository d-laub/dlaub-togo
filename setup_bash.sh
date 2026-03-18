#!/usr/bin/env bash

set -euo pipefail

curl -fsSL https://pixi.sh/install.sh | sh
curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh | sh

pixi g i ripgrep bat glow-md sd zoxide rnr gh fd-find exa prek