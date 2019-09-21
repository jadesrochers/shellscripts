#!/bin/bash
# Script for updating vim plugins that I have installed
# manually fromhub.

get_vimpack_dir () {
  find /home -xdev -type d -path "*/.vim/pack" 2>/dev/null | head -n 1
}

get_plugin_dirs () {
  local basedir="$(get_vimpack_dir)"
  if [[ ${#basedir} -lt 5 ]]; then
    printf %"sNo valid .vim/pack dir found, exiting\n"
    exit 1
  fi
  find "$1" -type d -path "*start/*" -prune -print -o -type d -path "*opt/*" -prune -print
}

setup_installs () {
  # make each of the base install directories, then 
  # have clone to each of those
  local basedir="$(get_vimpack_dir)" 
  local numgroups=${#groups[@]}
  i=0
  while [[ $i -lt $numgroups ]]; do
    curdir="${basedir}/${groups[$i]}/${startoropt[$i]}" 
    printf "\nCurrent dir:  %s\n" "$curdir"
    if [[ ! -d "$curdir" ]]; then
      mkdir -p "$curdir"
    fi
    git_clone "${!plugins[$i]}"
    i=$((i+1))
  done
}

git_clone () {
  # do the actual cloning to the appropriate directories
  while [[ $# -gt 0 ]]; do
    local url="$1"
    local curplug="${curdir}/${url##*/}"
    local urlexist="$(curl -s --head "$url" | head -n 1 | grep "HTTP/1.[01] [23]..")"
    printf "Current Plugin:  %s\n" "$curplug"

    if [[ -d "$curplug" && -d "$curplug/.git" ]]; then
      git_update "$curplug"      
    elif [[ ${#urlexist} -gt 2 ]]; then
      printf "Cloning %s to local dir %s\n" "$url" "$curdir"
      git clone "$url" "$curplug" 
    elif [[ ${#urlexist} -lt 2 ]]; then
      printf "Could not find repository URL:  %s,  moving to next\n" "$url"
    fi
    shift
  done
}

git_update () {
# Takes the paths for all the start/ and opt/ plugin paths for vim.
  pushd "$1" &> /dev/null
  git checkout master &> /dev/null
  if [[ $? -ne 0 ]]; then 
    printf "Could not checkout %s\n" "$1"
  else
    # printf "Pulling to update %s\n" "$1"
    git pull &> /dev/null
  fi
  popd &> /dev/null
}

groups=("codesyntax" "features" "colors")
startoropt=("start" "start" "opt")
grp1=("https://github.com/w0rp/ale" "https://github.com/junegunn/fzf" "https://github.com/valloric/youcompleteme")
grp2=("https://github.com/itchyny/lightline.vim" "https://github.com/scrooloose/nerdtree" "https://github.com/tpope/vim-commentary" "https://github.com/tpope/vim-fugitive")
grp3=("https://github.com/ayu-theme/ayu-vim" "https://github.com/morhetz/gruvbox" "https://github.com/arcticicestudio/nord-vim" "https://github.com/drewtempelmeyer/palenight.vim" "https://github.com/altercation/vim-colors-solarized" "https://github.com/rakr/vim-one")
plugins=(
grp1[@]
grp2[@]
grp3[@]
)

setup_installs

