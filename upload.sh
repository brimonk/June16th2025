#!/usr/bin/env bash

# This script is intended to be used with a cron job.

if [ ! -f ./.env ]; then
    echo "ERROR: We need an '.env' file in the current working directory to upload the meme."
    echo "ERROR:   The '.env' file requires:"
    echo "ERROR:   TOKEN_ID (bot token id)"
    echo "ERROR:   GUILD_ID (discord server id)"
    exit 1
fi

source .env

# compute the sound given the base sound, the day, the month, the year

# OLDSOUND is a file we'll test to determine if the bot has uploaded some other sound with a
# different id. If the file exists, we attempt to read its content as a sound id, and we try to
# remove it
#
# NOTE As of 03/31/2026, we want to actually just keep the old sound, so people can favorite it.
OLDSOUND=".OLDSOUND"

if [ -f $OLDSOUND ]; then
    OLDSOUNDID=$(cat $OLDSOUND)
else
    OLDSOUNDID=""
fi

function get_delay() {
    ffprobe -v error -show_entries format=duration -of csv=p=0 $1 | awk '{printf "%d\n", $1 * 1000}'
}

SOUND_NAME=$(date +%m-%d-%Y)

DAY=$(date +%d)
MONTH=$(date +%m)
YEAR=$(date +%Y)

DAY_FILE="./audio/day_${DAY}.mp3"
MONTH_FILE="./audio/month_${MONTH}.mp3"
YEAR_FILE="./audio/year_${YEAR}.mp3"

DAY_LENGTH_MS=$(get_delay ${DAY_FILE})
MONTH_LENGTH_MS=$(get_delay ${MONTH_FILE})
YEAR_LENGTH_MS=$(get_delay ${YEAR_FILE})

SEPTEMBER_SHORT="./audio/september_do_you_remember.mp3"

SEPTEMBER_LENGTH_MS=$(get_delay $SEPTEMBER_SHORT)

DELAY_MS=$(($SEPTEMBER_LENGTH_MS - $YEAR_LENGTH_MS - $MONTH_LENGTH_MS - $DAY_LENGTH_MS + 150))
OUTSOUND="outsound.mp3"

ffmpeg \
  -y \
  -i ${SEPTEMBER_SHORT} \
  -i ${MONTH_FILE} \
  -i ${DAY_FILE} \
  -i ${YEAR_FILE} \
  -filter_complex "
      [1:a][2:a][3:a]concat=n=3:v=0:a=1[clips];
      [clips]volume=9.0[clips];
      [clips]adelay=${DELAY_MS}|${DELAY_MS}[clips_delayed];
      [clips_delayed]equalizer=f=80:t=q:w=1:g=16,volume=30,acompressor=threshold=0dB:ratio=20:attack=1:release=50,bass=g=20[bass];
      [0:a]volume='if(lt(t,$DELAY_MS),5.0,1.8)'[september];
      [september][bass]amix=inputs=2[out]
    " \
  -map "[out]" $OUTSOUND

SOUND_B64=$(base64 -w 0 ./$OUTSOUND)

if [[ -z "${OLDSOUNDID}" ]]; then # create a new sound
    echo "creating new sound!"
    curl -X POST "https://discord.com/api/v10/guilds/$GUILD_ID/soundboard-sounds" \
        -H "Authorization: $TOKEN_ID" \
        -H "Content-Type: application/json" \
        -d "{\"name\":\"$SOUND_NAME\",\"emoji_name\":\"🎺\",\"sound\":\"data:audio/mpeg;base64,${SOUND_B64}\"}" \
        | jq -r '.sound_id' > $OLDSOUND
    echo "new sound id: " $(cat $OLDSOUND)
else
    echo "updating sound ${OLDSOUNDID}"
    curl -X PATCH "https://discord.com/api/v10/guilds/$GUILD_ID/soundboard-sounds/${OLDSOUNDID}" \
        -H "Authorization: $TOKEN_ID" \
        -H "Content-Type: application/json" \
        -d "{\"name\":\"$SOUND_NAME\",\"emoji_name\":\"🎺\",\"sound\":\"data:audio/mpeg;base64,${SOUND_B64}\"}" \
        | jq -r '.sound_id' > ${OLDSOUND}
fi
