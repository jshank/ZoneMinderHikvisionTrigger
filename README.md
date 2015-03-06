# ZoneMinderFoscamHDTrigger
Using Foscam HD inbuilt HW motion detection instead of Zoneminder's SW motion detection

 A trigger script that uses Foscam HD camera inbuilt motion detection
#  to start ZoneMinder recordings. When motion is detected, it records for 20seconds
#  (configurable).
#
#  Author: ARC
#  License: GPL
#  Version: 0.1
#  Date: Mar 6 2015
#
# More details:
# **** ONLY WORKS FOR FOSCAM HD CAMERAS. VERY EASY TO MAKE IT WORK WITH NON HD FOSCAMS too  ****
# to change to non HD cameras, just change URL construct of my($url) in line 114 (or close to it)
# (you will need to refer to your CGI document for it, that Foscam provides)
#
# Tested on: Ubuntu 14.04 running ZM 1.28.1
# Tested on: Foscam HD I9831W
#
# This is a script to use in conjunction with zoneminder trigger (zmtrigger.pl)
# This allows you to use Foscam HD camera motion detector instead of ZM's software motion detector
# I've been benchmarking both, and in general, I've found Foscams own built in HW motion detector
# superior to ZM's software (either that, or ZM's motion sensor has too many variables to play with)
#
#
# So anyway, I found out how to capture motion detection status from this document:
# http://foscam.us/forum/cgi-sdk-for-hd-camera-t6045.html
#
# There are many more goodies in the document.
#
#
# Summary: You need to set the Foscam HD camera to "enable Motion Detection", but don't enable
# recording in the camera, because you will be using ZM to record.
# Specifically, inside the camera:
# Alarm->Motion Detection: Enable, Sensitivity: High, Time Interval: 2s, UNCHECK Recording, Schedule: ALL
# Record->Alarm Recording: UNCHECK
# Record->Scheduled Recording: UNCHECK
#
# Please make sure your ZM monitor's are set to nodect for this script to initiate recordings

