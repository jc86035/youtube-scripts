#!/usr/bin/env zsh

export PATH="$HOME/bin:$PATH"
export TERASTASH_CASSANDRA_HOST=paris2.wg

# Use -4 to stick with IPv4 because YouTube blocks a lot of IPv6 ranges https://github.com/rg3/youtube-dl/issues/5138
youtube_dl_args=(-4 --sleep-interval 1 --socket-timeout 10 --title --continue --retries 30 --write-info-json --write-thumbnail --write-annotations --all-subs -f 'bestvideo[ext=webm]+bestaudio[ext=webm]/bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio/best' --ignore-errors)

tube-with-mtime() {
	YOUTUBE_DL_SKIP_LIVESTREAMS=1 \
	YOUTUBE_DL_RM_ALL_BEFORE_DL=1 \
	YOUTUBE_DL_TERASTASH=1 \
	low-pri youtube-dl --exec archive-youtube-download "$youtube_dl_args[@]" --max-downloads=${MAX_VIDEOS:-200} "$@"
}
tube-with-mtime-no-ts() {
	YOUTUBE_DL_SKIP_LIVESTREAMS=1 \
	low-pri youtube-dl "$youtube_dl_args[@]" --max-downloads=${MAX_VIDEOS:-200} "$@"
}
alias tube='tube-with-mtime --no-mtime'

get-new() {
	if [[ $PWD = $HOME/YouTube ]]; then
		echo "Refusing to run in ~/YouTube, did you want to cd to a subdirectory first?"
		return 1
	fi
	local user_or_chan_or_pl="$(basename "$(pwd)")"
	temp_log="$(mktemp)"
	local type="user/"
	suffix="/videos"
	if [[ "$1" != "user/" && $user_or_chan_or_pl == UC?????????????????????? ]]; then
		type="channel/"
	fi
	if [[ "$1" != "user/" && $user_or_chan_or_pl == [FPL]L* ]]; then
		type="playlist?list="
		suffix=""
	fi
	tube-with-mtime "https://www.youtube.com/$type$user_or_chan_or_pl$suffix" 2>&1 | tee "$temp_log"
	# Even though we have UC?????????????????????? or PL* above, we might still
	# have a UC* or PL* username instead, so try again as a user if needed.
	if [[ "$type" != "user/" && (
	"0" == $(grep -iq 'WARNING: Unable to download webpage: HTTP Error 404' "$temp_log"; echo $?) ||
	"0" == $(grep -iq 'ERROR: Invalid parameters. Maybe URL is incorrect.' "$temp_log"; echo $?)) ]]; then
		echo "Trying $user_or_chan_or_pl again as a user instead of a channel or playlist..."
		get-new user/
	fi
	rm -f "$temp_log"
}

# For terastash, highlight files with sticky bit set, so that we know which
# files have had their content zero'ed
alias ls=deleteme
unalias ls
ls() {
	LC_COLLATE=C /run/current-system/sw/bin/ls --block-size=\'1 -A --color=always -F --time-style=long-iso "$@" | GREP_COLORS="mt=0;37" grep -E --color -- '^.........T[+ ].*|$'
}

get-here() {
	ts ls -j | grep -P '\.(mp4|webm|flv|mkv|video)$' | grep -v YTNOAUDIO | sed -r 's/.*?(.{11})\.[^\.]+$/\1/g' | sort
}

alias gyc=grab-youtube-channel
gycall() {
	grab-youtube-channel "$1" 999999
}