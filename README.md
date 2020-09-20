# homerunhd-radio-hls-sonos
Takes [HDHomerun](https://www.silicondust.com/) (e.g. Quatro tuner) streams and converts to appropriate HLS stream for Sonos.
Use case:
As a UK user of HDHomerun Quatro tuner and with Sonos music players at home,
... I want to be able to use locally streamed UK Radio streams from the DTT multiplex decoded by the tuner on my home network and playback using Sonos (or other compatible stream player)
... so that I can avoid using public internet streams, with higher latency and potentially lower quality (than the DTT channel - which, in some cases isn't true).

Example:

HDHomerun Quatro on my network accepts stream requests via:
http://LOCALIPADDRESS:5004/auto/v[CHANNELNUMBER]

([More info on the HDHomerun HTTP API](https://info.hdhomerun.com/info/http_api))

e.g. To stream BBC Radio 2, which is on Channel 702 in the local DTT mux - I can call http://LOCALIPADDRESS:5004/auto/v702

However this stream is not supplied in a compatible format for Sonos (and other players).

With a bit of [FFMPEG](https://ffmpeg.org/) magic I can take that stream and create a live HLS stream as follows:

```shell
ffmpeg -hide_banner -loglevel fatal -i http://LOCALIPADDRESS:5004/auto/v702 -c:a libfdk_aac -profile:a aac_he_v2 -b:a 96k -ac 2 -f hls -hls_list_size 24 -hls_flags delete_segments+discont_start+temp_file -hls_time 2 stream.m3u8
```
This command will use libfdk_aac (Fraunhofer FDK AAC - which includes AAC-LC, HE-AACv1 and HE-AACv2) and, in this case, I'll use ```aac_he_v2``` profile to output a HE-AACv2 SBR+PS encoded audio (as Sonos can handle that, but I could use AAC-LC for some more compatibility - though packets will be larger). For more info on AAC in FFMPEG [check this out](https://trac.ffmpeg.org/wiki/Encode/AAC) - and you'll find that you can use the default AAC encoders rather than the FDK if you'd prefer.
It then outputs to HLS segmented streaming (default .ts chunks) duration of each chunk is 2 seconds (hls_time) - though I'm not being strict, and the outputs will pick the nearest frame and so it will be around 2 seconds.

FFMPEG will keep going until you kill it, and produce and update the stream.m3u8 master playlist, and create the appropriate ts chunks on the filesystem (```delete_segments``` tidies up after 24 segments - ```hls_list_size```).
Then all I need to do is expose this folder with the .m3u8 and the .ts chunks on a local webserver.

On my Sonos app (you'll need to use the Mac/Win app) - I can then add this 'Radio Station', which files it in the 'My Radio Stations' in TuneIn music provider. From there you can add it to your Favourites if you want.

Other things I've done here - I'm using a Mini-Mac for this (macOS) so this repo contains semi-portable code that will allow you to choose which channel to stream from the HDHomerun box and I've used macOS ```launchd``` to run the FFMPEG and restart it if it dies (which I abuse in my webserver PHP code to allow switching streams upon request). (If you want an easier GUI way of configuring ```launchd```, can I recommend [Lingon X](https://www.peterborgapps.com/lingon/) which makes things fairly easy.)


Configuration:
* in ```bin/stream_channel_hdhr.sh``` - you'll want to update these to point to your HDHomerun box (```urlprefix```) and where the htdocs/root of the webserver you want to make the M3U8 playlist and TS chunks available at (```folderpath```).
```shell
# change this to your HDHomerun location
urlprefix="http://192.168.86.25:5004/auto/v"
# change this path to where your webserver document root is - this is where the files will be deposited by ffmpeg
folderpath="/Users/alano/Sites/streamradio"
```
* in ```htdocs/stream.php``` -
  * you'll want to make sure the following line is updated - that path in there should match the path in ```folderpath``` from above - also, if you are wondering about ```[s]``` in the grep that just makes it specifically find the process that is actually streaming and not my grep for it.
```PHP
$pid = shell_exec("ps ex | grep -i '/bin/bash /Users/alano/Dropbox/[s]hscripts/stream_channel_hdhr.sh -f' | awk '{print $1}'");
```
  * you'll want to make sure that the webserver for this website is allowed to 'kill' processes - so you'll want to make sure that the shell script above is run by a user that the webserver can kill. (on my Mini-Mac for this I run the shell script as a regular user, and the webserver I use is a basic [MAMP setup](https://www.mamp.info/)). The stream.php script first checks if you've given it the channel on the ```querystring``` (eg. ```?channel=703```) then it checks ```htdocs/config/config.cfg``` which contains a simply string - the current channel number. If the channel requested is different from the one in the config file, the php code will update the ```config.cfg``` file with the new channel requested and kill the ```stream_channel_hdhr.sh``` process. Because I have this script monitored by ```launchd``` to restart if it dies, the script is started - and it checks the ```config.cfg``` file and takes the channel number from there when starting FFMPEG. If ```stream.php``` receives a channel number on the querystring that is the same as that in ```config.cfg``` it will assume everything is ok and simply return the M3U8.

Some issues I've found though:
* Sonos seems fine when the M3U8 and the chunks exist already, but trying to switch FFMPEG and delay the request seems to timeout on Sonos, but is fine if you test with QuickTime Player. So you may need to tap on the Live Radio favourite in Sonos again if FFMPEG is switching. If it's already streaming that channel it'll work seamlessly.
* The redirect at the end of ```stream.php``` is an attempt to solve the above Sonos timeout issue. Instead of actually redirecting (which I tried first, with the 'header - location') I actually return the contents of the M3U8 file using ```readfile```. This does mean that this particular php script will be constantly requested by the player - and, though it's not doing much - it does mean that it will check the ```config.cfg``` every time. Probably not too much of an issue, but feels like this could be more efficient somehow.
* My ffmpeg command doesn't bother to check if there's a video stream on the input, so if you tune to a channel with audio+video, you'll get ts chunks with audio and video - I noted that Sonos will actually stream the audio from this. I didn't bother fixing it.
* Since I'm using a Quatro box - that means there are several tuners embedded in it, though I'm strictly only ever trying to use one. But the HTTP API specs say this is handled, but may result in an error if there are no tuners available (other players are using streams from the all tuners on the hardware). I haven't handled the error gracefully (at all). I find that with a Quatro box I never really have all four tuners being taxed all the time, so I haven't bothered.
* This was a 'hack' and should be considered at that level of coding competency. :-)
