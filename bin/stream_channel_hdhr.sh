#!/bin/bash
# change this to your HDHomerun location
urlprefix="http://192.168.86.25:5004/auto/v"
# change this path to where your webserver document root is - this is where the files will be deposited by ffmpeg
folderpath="/Users/alano/Sites/streamradio"

# don't change below here...

OPTIND=1
me=$(basename "$0")

show_help() {
  cat << EOF

  Usage:

    ${me} [-c CHANNELNUMBER] [-f CONFIGFILE]

EOF
}

channelnumber="702"
configfileinuse=false

while getopts ":c:f:" opt; do
  case ${opt} in
    c)
      echo "RECEIVED: -c CHANNELNUMBER '${OPTARG}'" >&2
      channelnumber="${OPTARG}"
      ;;
      f)
        echo "RECEIVED: -f CONFIGFILE '${OPTARG}'" >&2
        configfile="${OPTARG}"
        configfileinuse=true
        ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      show_help
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      show_help
      exit 1
      ;;
  esac
done

if [ "${configfileinuse}" == true ]; then
  echo "############ GETTING CONFIG FROM FILE ###########"
  echo "FILE: ${configfile}"
  if [[ -f "${configfile}" ]]; then
      echo "File exists, reading now."
      IFS=$'\n' read -d '' -r -a configarr < "${configfile}"
      configval=""
      configval+=${configarr}
  else
    echo "File doesn't exist, this is a failure and script will exit. Nothing done."
    exit 1
  fi
else
  configval=${channelnumber}
fi

#echo ${configval}
inputstream="${urlprefix}${configval}"
echo "Attempting stream from: ${inputstream}"
cd ${folderpath}
rm -f *.m3u8
rm -f *.ts
rm -f *.tmp
/usr/local/bin/ffmpeg -hide_banner -loglevel fatal -i ${inputstream} -c:a libfdk_aac -profile:a aac_he_v2 -b:a 96k -ac 2 -f hls -hls_list_size 24 -hls_flags delete_segments+discont_start+temp_file -hls_time 2 stream.m3u8
rm -f *.m3u8
rm -f *.ts
