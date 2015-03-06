#!/bin/bash


#  zm_trigger crashes - some odd memory map error. This shell script just reloads it back
while true; do
/usr/bin/arc_zmtrigger.pl
echo "Restarting after crash..."
done

