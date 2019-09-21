#!/bin/bash

copyedits () {
  mv -u /home/jad/Dropbox/Tutorial_Edits/* /home/jad/Tutorial_Notes
}

if [[ ! -d /home/jad/Dropbox/Tutorial_Edits ||  ! -d /home/jad/Tutorial_Notes ]]; then
  printf %"sOne of the directories did not exist\n"
  exit 0  # exit without any action. 
fi

if [[ -n "$(ls -A /home/jad/Dropbox/Tutorial_Edits)" &&  "$(ls -A /home/jad/Tutorial_Notes)" ]]; then
  printf %"sCopying from Tutorial_Edits to the Tutorial_Notes dir\n"
  copyedits
fi

