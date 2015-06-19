#! /bin/bash

# a scrip to backup files to dropbox based on a set of criteria
# attempt to create a log with the exec method
# works, so long as the 2>&1 comes after initial creation
exec 1> $HOME/bin/log/dropBoxBack.log 2>&1

# If you want to add a file type, put it in here.
FileExtBin=("\.java" "\.sh" "\.txt" "\.css" "\.js" "\.html" "\.r")
FileExtDocs=("\.xlsx" "\.ods" "\.odt" "\.boot" "\.txt" "\.html" "\.pdf" "\.conf")
FileExtHome=("\.emacs" "\.bashrc" "\.inputrc" "authorized_keys.*")
Python=("\.py")

# for each file type, find only files less than 2Mb, 
# only normal files (no directories, links), and 
# then copy them with update (u), preserve (p) and verbose (v) options.
# currently do only files less than 100Kb

for j in ${FileExtBin[@]}; do 
find ${HOME}/bin -regextype sed -type f -not -path "*sec-scraper/SNOTEL_daily*" -size -100k -regex ".*/[^/]*$j$" | xargs -Ifile cp -uvp file ~/Dropbox
done

for j in ${FileExtDocs[@]}; do 
find ${HOME}/Documents -regextype sed -type f -size -100k -regex ".*/[^/]*$j$" | xargs -Ifile cp -uvp file ~/Dropbox
done

for j in ${FileExtHome[@]}; do 
find ${HOME} -regextype sed -type f -size -100k -regex ".*/[^/]*$j$" | xargs -Ifile cp -uvp file ~/Dropbox
done

find ${HOME}/bin/python -maxdepth 2 -regextype sed -type f -size -100k -regex ".*/[^/]*$Python$" | xargs -Ifile cp -uvp file ~/Dropbox


