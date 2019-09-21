#!/usr/bin/python
import pdb
import datetime
import sys

# get the starting date and time from first time stamp and start up time
startdt = datetime.datetime.strptime(sys.argv[1], '%Y-%m-%d %H:%M:%S.%f')
startdt_adj = startdt - datetime.timedelta(seconds=float(sys.argv[2]))

# get the end date and time from the most recent time stamp
enddt = datetime.datetime.strptime(sys.argv[3], '%Y-%m-%d %H:%M:%S.%f')

# actual processing time; difference in system times from start to current
diffdt = enddt - startdt_adj

# Get the corresponding time within the file; offset based on ticks.
offsets = sys.argv[4].split(':')
offsetdt = datetime.timedelta(hours=int(offsets[0]), minutes=int(offsets[1]), seconds=int(offsets[2]))

# The offset in file minus actual analysis time yields 
# negative values if we are behind analyzing. Larger negative, further behind.
print offsetdt.seconds - diffdt.seconds
