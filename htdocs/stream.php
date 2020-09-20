<?php
//example: http://192.168.86.248:8889/stream.php?channel=702
header("Content-Type: application/vnd.apple.mpegurl");
header('Content-Disposition: attachment; filename="stream.m3u8"');
// header("Accept-Ranges: bytes");
// header("Transfer-Encoding: chunked");
$currentchannelconfig="".file_get_contents ("config/channel.cfg");
$getchannel = isset($_GET['channel']) ? "".$_GET['channel'] : "702";
// echo "<p>This page called with channel=$getchannel</p>";
// echo "<pre>$currentchannelconfig</pre>";
if ($currentchannelconfig==$getchannel) {
  // echo "<p>same channel, don't do anything";
  // redirect to stream.m3u8
} else {
  echo "<p>different channel, do something";
  $pid = shell_exec("ps ex | grep -i '/bin/bash /Users/alano/Dropbox/[s]hscripts/stream_channel_hdhr.sh -f' | awk '{print $1}'");
  echo "<pre>$pid</pre>";
  // write new channel to config file (overwrite)
  file_put_contents("config/channel.cfg",$getchannel);
  $currentchannelconfig="".file_get_contents ("config/channel.cfg");
  echo "<pre>$currentchannelconfig</pre>";
  $output=posix_kill($pid,9);
  echo "<pre>$output</pre>";
  // Delete the m3u8 and associated ts files
  unlink("stream.m3u8");
  array_map('unlink', glob("*.ts"));
  // now wait a bit as the process will respawn and read the config
  // sleep(1);
  // wait and see if the master.m3u8 exists yet
  set_time_limit(0);
  do {
    if (file_exists("stream1.ts")) {
        //the a ts chunk was found on the filesystem
        break;
    }
  } while(!file_exists("stream1.ts"));
  // then redirect to stream.m3u8
}
//header("Location: /stream.m3u8"); -- this doesn't seem to be liked by Sonos
readfile("./stream.m3u8");
exit();
?>
