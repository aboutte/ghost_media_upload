https://pacoup.com/2011/06/12/list-of-true-169-resolutions/

# This NEEDS to be a ruby script.  Features I want are:
- auto rotate video
- switch for setting the cut start and stop seconds
- switch for setting the output file type

ffmpeg -i %filltext:name=field 1% -s 640x480 -c:v libx264 -crf 25 -c:a aac -movflags faststart _c.mp4


cut / trim video
ffmpeg -i IMG_2856.m4v -ss 00:00:03 -t 00:00:18 -async 1 cut_IMG_2856.m4v

rotate video

ffmpeg -i in.mov -vf "transpose=1" out.mov

0 = 90CounterCLockwise and Vertical Flip (default)
1 = 90Clockwise
2 = 90CounterClockwise
3 = 90Clockwise and Vertical Flip