#!/usr/bin/env zsh

export PATH="$HOME/bin:$PATH"
export TERASTASH_CASSANDRA_HOST=finssd1.wg

# Use -4 to stick with IPv4 because YouTube blocks a lot of IPv6 ranges https://github.com/rg3/youtube-dl/issues/5138
youtube_dl_args=(\
	--user-agent "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/78.0.3904.70 Safari/537.36"
	--force-ipv4
	--sleep-interval 0.5
	--socket-timeout 20
	-o "%(title)s-%(id)s.%(ext)s"
	--continue
	--retries 30
	--write-info-json
	--write-thumbnail
	--write-annotations
	--all-subs
	-f 'bestvideo[ext=webm]+bestaudio[ext=webm]/bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio/best'
	--ignore-errors
)

youtube-dl() {
	# use choom to make the OOM killer more likely to target youtube-dl
	PYTHONPATH=$HOME/youtube-dl nice -n 5 choom -n +800 -- python3 -m youtube_dl "$@"
}

tube-with-mtime() {
	echo "Running on $HOST"
	YOUTUBE_DL_SKIP_LIVESTREAMS=1 \
	YOUTUBE_DL_RM_ALL_BEFORE_DL=1 \
	YOUTUBE_DL_TERASTASH=1 \
	youtube-dl --proxy "$(shuf -n 1 ~/.config/youtube-dl/proxies)" --exec archive-youtube-download "$youtube_dl_args[@]" --max-downloads=${MAX_VIDEOS:-200} "$@"
	echo "youtube-dl finished with exit status $?"
}
tube-with-mtime-no-ts() {
	YOUTUBE_DL_SKIP_LIVESTREAMS=1 \
	youtube-dl --proxy "$(shuf -n 1 ~/.config/youtube-dl/proxies)" "$youtube_dl_args[@]" --max-downloads=${MAX_VIDEOS:-200} "$@"
}
alias tube='tube-with-mtime --no-mtime'

rpick() {
	session=$(for i in $(tmux list-sessions -F '#S' | grep -v -P '^YouTube-'); do
		echo -e -n "$i\t"; { { tmux capture-pane -p -t "$i" | tr '\n' ' ' } || true }
		echo
	done | fzf --exact --reverse | cut -f 1)
	if [[ "$session" != "" ]]; then
		tmux attach -t "$session"
	fi
}

# Some say "your country", others say "video is available in" with
# a country list; 14UBUyF16Nk says "This video is not available"
# Channels like https://www.youtube.com/user/uverworldSMEJ/videos
# are completely geoblocked and show "Downloading 0 videos"
COMPLAINT_REGEXP='( bailing out\.\.\.|your country|video is available in|video is not available|Downloading 0 videos|Connection reset by peer|node_modules/cassandra-driver|CalledProcessError|Connection refused|Remote end closed connection without response)'

retry-tube-with-mtime() {
	temp_log="$(mktemp)"
	tube-with-mtime "$@" 2>&1 | tee "$temp_log"
	for i in $(seq 5); do
		if grep -iqP "$COMPLAINT_REGEXP" "$temp_log"; then
			echo
			echo "Saw some problem, grabbing again..."
			tube-with-mtime "$@" 2>&1 | tee "$temp_log"
		fi
	done
}

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
	for i in $(seq 3); do
		if grep -iqP "$COMPLAINT_REGEXP" "$temp_log"; then
			echo
			echo "Saw some problem, grabbing again..."
			tube-with-mtime "https://www.youtube.com/$type$user_or_chan_or_pl$suffix" 2>&1 | tee "$temp_log"
		fi
	done

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
