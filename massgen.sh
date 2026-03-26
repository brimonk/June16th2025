#!/usr/bin/env bash

# not used - but was used in testing the ffmpeg portion of the script

mkdir -pv testout
rm ./testout/*

SEPTEMBER_SHORT="./audio/september_do_you_remember.mp3"

function get_delay() {
    ffprobe -v error -show_entries format=duration -of csv=p=0 $1 | awk '{printf "%d\n", $1 * 1000}'
}

SEPTEMBER_LENGTH_MS=$(get_delay $SEPTEMBER_SHORT)

for k in $(find audio -iname "year*.mp3"); do
    YEAR=$(echo $k | sed -re 's/[.]mp3//g ; s/.*_([0-9]+).*/\1/')
    YEAR_LENGTH_MS=$(get_delay $k)

    for i in $(find audio -iname "month*.mp3"); do
        MONTH=$(echo $i | sed -re 's/[.]mp3//g ; s/.*_([0-9]+).*/\1/')
        MONTH_LENGTH_MS=$(get_delay $i)

        for j in $(find audio -iname "day*.mp3"); do
            DAY=$(echo $j | sed -re 's/[.]mp3//g ; s/.*_([0-9]+).*/\1/')
            DAY_LENGTH_MS=$(get_delay $j)

            OUTPUT="$YEAR-$MONTH-$DAY"

            DELAY_MS=$(($SEPTEMBER_LENGTH_MS - $YEAR_LENGTH_MS - $MONTH_LENGTH_MS - $DAY_LENGTH_MS))

              # -filter_complex "
              #   [1:a][2:a][3:a]concat=n=3:v=0:a=1[clips];
              #   [clips]aformat=channel_layouts=stereo[clips_fixed];
              #   [clips]adelay=delays=${DELAY_MS}:all=2[clips_delayed];
              #   [0:a][clips_delayed]sidechaincompress=threshold=0.1:ratio=4:attack=200:release=1000[out]
              # " \

            ffmpeg \
              -i $SEPTEMBER_SHORT \
              -i $k \
              -i $i \
              -i $j \
              -filter_complex "
                  [2:a][3:a][1:a]concat=n=3:v=0:a=1[clips];
                  [clips]volume=9.0[clips];
                  [clips]adelay=${DELAY_MS}|${DELAY_MS}[clips_delayed];
                  [clips_delayed]equalizer=f=80:t=q:w=1:g=16,volume=30,acompressor=threshold=0dB:ratio=20:attack=1:release=50,bass=g=20[bass];
                  [0:a]volume='if(lt(t,$DELAY_MS),5.0,1.8)'[september];
                  [september][bass]amix=inputs=2[out]
                " \
              -map "[out]" ./testout/${OUTPUT}.mp3

            echo $YEAR/$MONTH/$DAY
        done
    done
done

