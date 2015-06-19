#! /bin/bash

# a script to check for mismatches between java source
# files and .class files to clean up the latter when
# the former is no longer around. Also checks for files
# with repeated names and get rid of the older one if applicable

# some detail: I could not get this to work for quite some damn time
# because I could not figure the for loop delimiter. It uses spaces. 
# Also, this can be changed by editing shell variable IFS=$'\n'
# awk prints spaces by default when fields separated by commas.
# can also use printf
DIR1=~/Documents/Java_Programs/secFilingSource/
DIR2=~/Documents/Java_Programs/secFilingAnalysis/ # dont quote pathnames
# when unquoted the system expands to full path

# get the names of the editor temporary files
TEMPFILES="$(ls -l $DIR1 | awk '/.*(.java|.txt)~$/  {print $9}')"

# both of these formats work fine to create an array
CURRJAVA=($(ls -l $DIR1 | awk '/.*.java$/  {print $9}'))
CURRCLASS=($(ls $DIR2)) # should just be class files in here.

# in order to make this work, needed to be sure TEMPFILES was
# space delimited as this is going to be the default for bash and 
# for loop creation. This loop is not completely necessary, could 
# use exec or something else. Just going to demonstrate it anyway.

for j in $TEMPFILES; do
# loop to remove all the temporary editor file, gedit, may need to add emac 
# when I start editing with that too
    echo "$j"
    rm  ${DIR1}${j} 
    #dont quote combined pathnames
done

# the way to make this work was with the /*, which was
# indicated as some sort of globbing fcn in the tutorial
# THIS DOES WORK: I just dont know what the /* does.
# LIST="$(ls *.txt)"
# for i in $LIST/*; do
#     cat "$i"
# done

# Check for java files that match the name of each class file. If there
# isnt one, then get rid of the class file. String comparisons should
# be case sensitive. 
 
# outer loop will use each class file.
for j in ${CURRCLASS[*]}; do
    SAME=0
    # echo $j
    # cant feed this any quotes or $, just give the variable
    jTRUNC=${j%%[$.]*} # get the file name, not the extension
    # this will also ignore internal classes that are in active main class.
    # inner loop will check the source files for match to .class file.
    for j1 in ${CURRJAVA[*]}; do
	# echo $j1
	j1TRUNC=${j1%%.*} # file name without extension
	# the spaces matter with if/for statement logicals
	# double brackets works here, single will not
	if [[ $jTRUNC < $j1TRUNC || $jTRUNC > $j1TRUNC ]]; then
	    continue  # If you want to continue nesting loop, # after indicates
	else   
	    echo "checking to see if strings equal"
	    if [ $jTRUNC == $j1TRUNC ]; then SAME=1; break; fi
	fi

    done
    echo $SAME
    if [[ $SAME -eq 1 ]]; then echo "leave it be"; else echo "taking it out $DIR2 $j";  rm ${DIR2}${j}; fi
done

