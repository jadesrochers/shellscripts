# Find zipped files in a directory
# Create directories based on zip file names, then unzip to those directories.
# Notice the setting of the IFS to newline to allow space ignoring. That gave me a few fits later on.

dirwithzips="/home/jadesrochers/Downloads/"
dirtounzip="/home/jadesrochers/bin/python/personalwebsite/flaskapp/static/img/design/"
IFS=$'\n'
filenames=($(find $dirwithzips -maxdepth 1 -name '*zip'))
for j in ${filenames[@]}; do
  filename=$(basename "$j"); echo "Full file name: $filename"
  pathstr=$(dirname "$j");  echo "Full path: $pathstr"
  nameonly=${filename%.*}; echo "Name without extension: $nameonly"
  # use the first if there is a nested zip structure, second otherwise
  destdir="${dirtounzip}"; echo "Dir to create and save to: $destdir"
  # destdir="${dirtounzip}${nameonly}"; echo "Dir to create and save to: $destdir"
  mkdir "$destdir"; echo "Created directory $destdir"
  unzip $j -d "$destdir"
done
