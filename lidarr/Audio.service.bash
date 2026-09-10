#!/usr/bin/with-contenv bash
scriptVersion="2.52"
scriptName="Audio"

### Import Settings
source /config/extended.conf
#### Import Functions
source /config/extended/functions

AddTag () {
  log "adding arr-extended tag"
  lidarrProcessIt=$(curl -s  "$arrUrl/api/v1/tag" --header "X-Api-Key:"${arrApiKey} -H "Content-Type: application/json" --data-raw '{"label":"arr-extended"}')
}

AddDownloadClient () {
  downloadClientsData=$(curl -s  "$arrUrl/api/v1/downloadclient" --header "X-Api-Key:"${arrApiKey} -H "Content-Type: application/json")
  downloadClientCheck="$(echo $downloadClientsData | grep "Arr-Extended")"
  if [ -z "$downloadClientCheck" ]; then
    AddTag
    if [ ! -d "$importPath" ]; then
      mkdir -p "$importPath"
      chmod 777 -R "$importPath"
    fi
	log "Adding download Client"
    lidarrProcessIt=$(curl -s "$arrUrl/api/v1/downloadclient" --header "X-Api-Key:"${arrApiKey} -H "Content-Type: application/json" --data-raw "{\"enable\":true,\"protocol\":\"usenet\",\"priority\":10,\"removeCompletedDownloads\":true,\"removeFailedDownloads\":true,\"name\":\"Arr-Extended\",\"fields\":[{\"name\":\"nzbFolder\",\"value\":\"$importPath\"},{\"name\":\"watchFolder\",\"value\":\"$importPath\"}],\"implementationName\":\"Usenet Blackhole\",\"implementation\":\"UsenetBlackhole\",\"configContract\":\"UsenetBlackholeSettings\",\"infoLink\":\"https://wiki.servarr.com/lidarr/supported#usenetblackhole\",\"tags\":[]}")
 fi
}

verifyConfig () {
  ### Import Settings
  source /config/extended.conf
  if [ "$enableAudio" != "true" ]; then
    log "Script is not enabled, enable by setting enableAudio to \"true\" by modifying the \"/config/extended.conf\" config file..."
    log "Sleeping (infinity)"
    sleep infinity
  fi

  if [ -z "$audioScriptInterval" ]; then
    audioScriptInterval="15m"
  fi

  if [ -z "$downloadPath" ]; then
    downloadPath="/config/extended/downloads"
  fi

  if [ -z "$importPath" ]; then
    importPath="/config/extended/import"
  fi

  if [ -z "$failedDownloadAttemptThreshold" ]; then
  	failedDownloadAttemptThreshold="6"
  fi

  if [ -z "$tidalClientTestDownloadId" ]; then
  	tidalClientTestDownloadId="166356219"
  fi

  if [ -z "$deezerClientTestDownloadId" ]; then
  	deezerClientTestDownloadId="197472472"
  fi

  if [ -z "$ignoreInstrumentalRelease" ]; then
  	ignoreInstrumentalRelease="true"
  fi

  if [ -z "$downloadClientTimeOut" ]; then
  	downloadClientTimeOut="10m" # if not set, set to 10 minutes
  fi

  if [ -z "$preferSpecialEditions" ]; then
    preferSpecialEditions="true"
  fi

  if [ -z "$retryNotFound" ]; then
    retryNotFound="90"
  fi

  if [ -z "$youtubeVpnProxy" ]; then
    youtubeVpnProxy=""
  fi

  if [ -z "$proxyAllDownloadClients" ]; then
    proxyAllDownloadClients="false"
  fi

  if [ -z "$youtubeMatchThreshold" ]; then
    youtubeMatchThreshold="0.30"
  fi

  if [ -z "$youtubeDurationTolerance" ]; then
    youtubeDurationTolerance="15"
  fi

  if [ -z "$youtubeSearchResults" ]; then
    youtubeSearchResults="8"
  fi

  if [ -z "$youtubeYtdlpArgs" ]; then
    youtubeYtdlpArgs=""
  fi

  audioPath="$downloadPath/audio"
  tidalerConfigDir="/config/extended/tidaler"
  tidalerConfigFile="${tidalerConfigDir}/config.json"
  tidalerConfigTemplate="/config/extended/tidaler.json"


}

dlClientSetup () {
	# Parse $dlClientSource (space/comma separated list) into the ordered,
	# de-duplicated dlClients[] array.
	#   valid clients: deezer tidal youtube
	#   "both" is still accepted and expands to "deezer tidal"
	local raw c seen
	local -a out
	raw="${dlClientSource,,}"
	raw="${raw//,/ }"
	dlClients=()
	for c in $raw; do
		case "$c" in
			both)                 dlClients+=("deezer" "tidal") ;;
			deezer|tidal|youtube) dlClients+=("$c") ;;
			"")                   : ;;
			*) log "WARNING :: dlClientSource :: unknown client \"$c\" (valid: deezer tidal youtube both) -- ignoring" ;;
		esac
	done
	seen=" "
	out=()
	for c in "${dlClients[@]}"; do
		case "$seen" in
			*" $c "*) continue ;;
		esac
		out+=("$c")
		seen="$seen$c "
	done
	dlClients=("${out[@]}")
}

clientEnabled () {
	local c
	for c in "${dlClients[@]}"; do
		[ "$c" == "$1" ] && return 0
	done
	return 1
}

Configuration () {
	sleepTimer=0.5
	tidaldlFail=0
	deemixFail=0
	youtubedlFail=0
	log "-----------------------------------------------------------------------------"
	log " |~) _ ._  _| _ ._ _ |\ |o._  o _ |~|_|_|"
	log " |~\(_|| |(_|(_)| | || \||| |_|(_||~| | |<"
	log " Presents: $scriptName ($scriptVersion)"
	log " May the beats be with you!"
	log "-----------------------------------------------------------------------------"
	log "Donate: https://github.com/sponsors/RandomNinjaAtk"
	log "Project: https://github.com/RandomNinjaAtk/arr-scripts"
	log "Support: https://github.com/RandomNinjaAtk/arr-scripts/discussions"
	log "-----------------------------------------------------------------------------"
	sleep 5
	log ""
	log "Lift off in..."; sleep 0.5
	log "5"; sleep 1
	log "4"; sleep 1
	log "3"; sleep 1
	log "2"; sleep 1
	log "1"; sleep 1
	
	
	
	if [ ! -d /config/extended ]; then
		mkdir -p /config/extended
	fi
	if [ ! -d "$tidalerConfigDir" ]; then
		mkdir -p "$tidalerConfigDir"
	fi
 
	if [ -z $topLimit ]; then
		topLimit=10
	fi

	verifyApiAccess
	AddDownloadClient

	if [ "$addDeezerTopArtists" == "true" ]; then
		log "Add Deezer Top $topLimit Artists is enabled"
	else
		log "Add Deezer Top Artists is disabled (enable by setting addDeezerTopArtists=true)"
	fi

	if [ "$addDeezerTopAlbumArtists" == "true" ]; then
		log "Add Deezer Top $topLimit Album Artists is enabled"
	else
		log "Add Deezer Top Album Artists is disabled (enable by setting addDeezerTopAlbumArtists=true)"
	fi

	if [ "$addDeezerTopTrackArtists" == "true" ]; then
		log "Add Deezer Top $topLimit Track Artists is enabled"
	else
		log "Add Deezer Top Track Artists is disabled (enable by setting addDeezerTopTrackArtists=true)"
	fi

	if [ "$addRelatedArtists" == "true" ]; then
		log "Add Deezer Related Artists is enabled"
		log "Add $numberOfRelatedArtistsToAddPerArtist Deezer related Artist for each Lidarr Artist"
	else
		log "Add Deezer Related Artists is disabled (enable by setting addRelatedArtists=true)"
	fi
	
	log "Download Location: $audioPath"


	log "Output format: $audioFormat"

	if [ "$audioFormat" != "native" ]; then 
		if [ "$audioFormat" == "alac" ]; then
			audioBitrateText="LOSSLESS"
		else
			audioBitrateText="${audioBitrate}k"
		fi
	else
		audioBitrateText="$audioBitrate"
  	fi
	log "Output bitrate: $audioBitrateText"

	if [ "$requireQuality" == "true" ]; then
		log "Download Quality Check Enabled"
	else
		log "Download Quality Check Disabled (enable by setting: requireQuality=true"
	fi

	if [ "$audioLyricType" == "both" ] || [ "$audioLyricType" == "explicit" ] || [ "$audioLyricType" == "explicit" ]; then
		log "Preferred audio lyric type: $audioLyricType"
	fi
	log "Tidal Country Code set to: $tidalCountryCode"

	if [ "$enableReplaygainTags" == "true" ]; then
		log "Replaygain Tagging Enabled"
	else
		log "Replaygain Tagging Disabled"
	fi

	log "Match Distance: $matchDistance"

	if [ $enableBeetsTagging = true ]; then
		log "Beets Tagging Enabled"
		log "Beets Matching Threshold ${beetsMatchPercentage}%"
		# strong_rec_thresh is a max distance, i.e. the inverse of the match percentage.
		# Zero-pad so 95% becomes 0.05 and not 0.5
		if [ "$beetsMatchPercentage" -lt 1 ]; then
			beetsMatchPercentage=1
		fi
		if [ "$beetsMatchPercentage" -gt 100 ]; then
			beetsMatchPercentage=100
		fi
		printf -v beetsMatchDistance "0.%02d" "$(( 100 - beetsMatchPercentage ))"
		# Match whatever value is currently in the file, not a hard-coded default,
		# so this keeps working after the shipped default changes or we run again
		if ! grep -q "strong_rec_thresh: ${beetsMatchDistance}" /config/extended/beets-config.yaml; then
			log "Configuring Beets Matching Threshold ($beetsMatchDistance)"
			sed -i "s/strong_rec_thresh: [0-9.]*/strong_rec_thresh: ${beetsMatchDistance}/" /config/extended/beets-config.yaml
		fi
	else
		log "Beets Tagging Disabled"
	fi

	if [ "$preferSpecialEditions" == "true" ]; then
      log "Prefer Special Editions Enabled"
	else
      log "Prefer Special Editions Disabled"
	fi

 	log "Failed Download Attempt Threshold: $failedDownloadAttemptThreshold"

	dlClientSetup
	NotFoundMigration
	if [ ${#dlClients[@]} -eq 0 ]; then
		log "ERROR :: No valid dlClientSource set (got: \"$dlClientSource\")"
		log "ERROR :: Set dlClientSource to any of: deezer tidal youtube both (space or comma separated)"
		NotifyWebhook "FatalError" "No valid dlClientSource set"
		log "Script sleeping for $audioScriptInterval..."
		sleep $audioScriptInterval
		exit
	fi
	log "Download Client(s): ${dlClients[*]}"

}

ProxyOn () {
	# Opt-in: route the heavy download clients (deemix/freyr/tidal-dl) through
	# the same VPN proxy as yt-dlp. Off by default -- deezer/tidal are API-key
	# authed and work fine direct. yt-dlp is always proxied via its own --proxy
	# flag, never through these env vars. Metadata/API curl calls are never
	# wrapped, so they stay direct regardless.
	if [ "$proxyAllDownloadClients" == "true" ] && [ -n "$youtubeVpnProxy" ]; then
		export HTTP_PROXY="$youtubeVpnProxy" HTTPS_PROXY="$youtubeVpnProxy" http_proxy="$youtubeVpnProxy" https_proxy="$youtubeVpnProxy"
	fi
}

ProxyOff () {
	unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy
}

DownloadClientFreyr () {
	ProxyOn
	timeout $downloadClientTimeOut freyr --no-bar --no-net-check -d $audioPath/incomplete deezer:album:$1 2>&1 | tee -a "/config/logs/$logFileName"
	ProxyOff
 	# Resolve issue 94
 	if [ -d /root/.cache/FreyrCLI ]; then
  		rm -rf  /root/.cache/FreyrCLI/*
        fi
}

YtdlpFormatArgs () {
	# Honour the configured output format directly -- yt-dlp can only extract
	# FROM its download, and the flac->X transcode step further down never sees
	# YouTube's opus/m4a. "native" keeps the best available lossy codec.
	ytFmtArgs=()
	case "$audioFormat" in
		native) ytFmtArgs=(--audio-quality 0) ;;
		mp3)    ytFmtArgs=(--audio-format mp3  --audio-quality "${audioBitrate}k") ;;
		aac)    ytFmtArgs=(--audio-format aac  --audio-quality "${audioBitrate}k") ;;
		opus)   ytFmtArgs=(--audio-format opus --audio-quality "${audioBitrate}k") ;;
		alac)   ytFmtArgs=(--audio-format alac) ;;
		*)      ytFmtArgs=(--audio-quality 0) ;;
	esac
}

DownloadClientYoutube () {
	# $1 = synthetic id "yt-<albumMBID>" -- the matched per-track list was written
	#      by YoutubeSearch to /config/extended/cache/youtube/<albumMBID>.tracks
	#      as TAB-separated  <youtubeVideoId>\t<zero-padded output basename>
	local matchFile="/config/extended/cache/youtube/${1#yt-}.tracks"
	if [ ! -f "$matchFile" ]; then
		log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: YOUTUBE :: ERROR :: match list missing ($matchFile)"
		return
	fi

	ytdlpProxyArgs=()
	[ -n "$youtubeVpnProxy" ] && ytdlpProxyArgs=(--proxy "$youtubeVpnProxy")
	ytdlpCookieArgs=()
	[ -n "$youtubeCookiesFile" ] && ytdlpCookieArgs=(--cookies "$youtubeCookiesFile")
	ytdlpExtraArgs=()
	[ -n "$youtubeYtdlpArgs" ] && read -ra ytdlpExtraArgs <<< "$youtubeYtdlpArgs"
	YtdlpFormatArgs

	local ytId ytBase rc consecFail=0
	while IFS=$'\t' read -r ytId ytBase; do
		[ -z "$ytId" ] && continue
		if find "$audioPath/incomplete" -maxdepth 1 -type f -name "${ytBase}.*" | read; then
			consecFail=0
			continue   # already fetched on a previous attempt
		fi
		log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: YOUTUBE :: Downloading $ytBase (yt:$ytId)"
		timeout "$downloadClientTimeOut" yt-dlp \
			-f "bestaudio/best" -x "${ytFmtArgs[@]}" \
			--no-playlist --retries 4 --fragment-retries 4 --sleep-requests 1 \
			"${ytdlpProxyArgs[@]}" "${ytdlpCookieArgs[@]}" "${ytdlpExtraArgs[@]}" \
			--embed-metadata --embed-thumbnail --no-mtime --geo-bypass --no-warnings \
			-o "$audioPath/incomplete/${ytBase}.%(ext)s" \
			-- "$ytId" 2>&1 | tee -a "/config/logs/$logFileName"
		rc=${PIPESTATUS[0]}
		if [ "$rc" -ne 0 ] && ! find "$audioPath/incomplete" -maxdepth 1 -type f -name "${ytBase}.*" | read; then
			consecFail=$(( consecFail + 1 ))
			if [ "$consecFail" -ge 3 ]; then
				log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: YOUTUBE :: ERROR :: 3 consecutive yt-dlp failures (likely bot-check / IP block) -- aborting this album. Add authenticated cookies to /config/cookies.txt"
				break
			fi
		else
			consecFail=0
		fi
	done < "$matchFile"
}

DownloadFormat () {

	if [ "$audioFormat" == "native" ]; then
		if [ "$audioBitrate" == "master" ]; then
			tidalQuality=HI_RES_LOSSLESS
			deemixQuality=flac
		elif [ "$audioBitrate" == "lossless" ]; then
			tidalQuality=LOSSLESS
			deemixQuality=flac
		elif [ "$audioBitrate" == "high" ]; then
			tidalQuality=HIGH
			deemixQuality=320
		elif [ "$audioBitrate" == "low" ]; then
			tidalQuality=LOW
			deemixQuality=128
		else
			log "ERROR :: Invalid audioFormat and audioBitrate options set..."
			log "ERROR :: Change audioBitrate to a low, high, or lossless..."
			log "ERROR :: Exiting..."
			NotifyWebhook "FatalError" "Invalid audioFormat and audioBitrate options set"
			log "Script sleeping for $audioScriptInterval..."
			sleep $audioScriptInterval
			exit
		fi
	else
		bitrateError="false"
		audioFormatError="false"
		tidalQuality=LOSSLESS
		deemixQuality=flac

		case "$audioBitrate" in
			lossless | high | low)
				bitrateError="true"
				;;
			*)
				bitrateError="false"
				;;
		esac

		if [ "$bitrateError" == "true" ]; then
			log "ERROR :: Invalid audioBitrate options set..."
			log "ERROR :: Change audioBitrate to a desired bitrate number, example: 192..."
			log "ERROR :: Exiting..."
			NotifyWebhook "FatalError" "audioBitrate options set"
   			log "Script sleeping for $audioScriptInterval..."
			sleep $audioScriptInterval
			exit
		fi

		case "$audioFormat" in
			mp3 | alac | opus | aac)
				audioFormatError="false"
				;;
			*)
				audioFormatError="true"
				;;
		esac

		if [ "$audioFormatError" == "true" ]; then		
			log "ERROR :: Invalid audioFormat options set..."
			log "ERROR :: Change audioFormat to a desired format (opus or mp3 or aac or alac)"
			NotifyWebhook "FatalError" "audioFormat options set"
   			log "Script sleeping for $audioScriptInterval..."
			sleep $audioScriptInterval
			exit
		fi

		XDG_CONFIG_HOME=/config/extended tidaler cfg quality_audio LOSSLESS 2>&1 | tee -a "/config/logs/$logFileName"
		deemixQuality=flac
		bitrateError=""
		audioFormatError=""
	fi
}

DownloadFolderCleaner () {
	# check for completed download folder
	if [ -d "$audioPath/complete" ]; then
		log "Removing prevously completed downloads that failed to import..."
		# check for completed downloads older than 1 day
		if find "$audioPath"/complete -mindepth 1 -type d -mtime +1 | read; then
			# delete completed downloads older than 1 day, these most likely failed to import due to Lidarr failing to match
			find "$audioPath"/complete -mindepth 1 -type d -mtime +1 -exec rm -rf "{}" \; &>/dev/null
		fi
	fi
}

NotFoundFolderCleaner () {
	if [ -z "$retryNotFound" ]; then retryNotFound="90"; fi
	if [ -d /config/extended/logs/notfound ]; then
		# Per-client markers: <albumId>--<artistMBID>--<albumMBID>--<client>
		# Deleting one client's marker re-opens only that client for the album.
		if find /config/extended/logs/notfound -mindepth 1 -type f -name '*--*--*--*' -mtime +$retryNotFound | read; then
			log "Removing per-client notfound markers older than $retryNotFound days to give them a retry..."
			find /config/extended/logs/notfound -mindepth 1 -type f -name '*--*--*--*' -mtime +$retryNotFound -delete
		fi
		# Legacy suffix-less markers that escaped NotFoundMigration
		if find /config/extended/logs/notfound -mindepth 1 -type f ! -name '*--*--*--*' -mtime +$retryNotFound | read; then
			log "Removing legacy notfound markers older than $retryNotFound days..."
			find /config/extended/logs/notfound -mindepth 1 -type f ! -name '*--*--*--*' -mtime +$retryNotFound -delete
		fi
	fi
}

NotFoundMigration () {
	# One-time: convert pre-2.49 album-level markers (<id>--<aMBID>--<albMBID>)
	# into per-client markers. Only deezer/tidal could have produced them, so a
	# newly-added youtube client still gets a fresh attempt at those albums.
	local dir="/config/extended/logs/notfound"
	[ -d "$dir" ] || return
	local f base migrated=0
	for f in "$dir"/*; do
		[ -f "$f" ] || continue
		base="$(basename "$f")"
		case "$base" in
			*--deezer|*--tidal|*--youtube) continue ;;
		esac
		if [[ "$base" == *--*--* ]]; then
			touch "$dir/$base--deezer" "$dir/$base--tidal"
			chmod 777 "$dir/$base--deezer" "$dir/$base--tidal" 2>/dev/null
			rm -f "$f"
			migrated=$(( migrated + 1 ))
		fi
	done
	[ "$migrated" -gt 0 ] && log "NOTFOUND MIGRATION :: Converted $migrated legacy marker(s) to --deezer + --tidal"
}

BuildNotFoundExhaustedList () {
	# $1 = output file. Writes the sorted-unique list of lidarr album IDs that
	# have a notfound marker for EVERY client in dlClients[] (fully exhausted).
	# Empty dlClients[] -> empty output (nothing is excluded).
	local outFile="$1"
	local markerDir="/config/extended/logs/notfound"
	local accFile="/config/extended/cache/nf-exhausted-acc.txt"
	local curFile="/config/extended/cache/nf-exhausted-cur.txt"
	: > "$outFile"
	[ ${#dlClients[@]} -eq 0 ] && return
	mkdir -p "$markerDir"
	local client first="true"
	: > "$accFile"
	for client in "${dlClients[@]}"; do
		ls -1 "$markerDir"/ 2>/dev/null | grep -E -- "--${client}\$" | sed -E 's/--.*//' | sort -u > "$curFile"
		if [ "$first" == "true" ]; then
			cp "$curFile" "$accFile"
			first="false"
		else
			comm -12 "$accFile" "$curFile" > "$accFile.next"
			mv "$accFile.next" "$accFile"
		fi
	done
	sort -u "$accFile" > "$outFile"
	rm -f "$accFile" "$accFile.next" "$curFile"
}

TidalClientSetup () {
	log "TIDAL :: Verifying tidaler configuration"
	touch "${tidalerConfigDir}/tidaler.log"
	if [ -f "$tidalerConfigFile" ]; then
		rm "$tidalerConfigFile"
	fi
	if [ ! -f "$tidalerConfigFile" ]; then
		log "TIDAL :: No default config found, importing default config \"tidaler.json\""
		if [ -f "$tidalerConfigTemplate" ]; then
			cp "$tidalerConfigTemplate" "$tidalerConfigFile"
			chmod 777 -R "$tidalerConfigDir"
		fi

	fi
	
	TidalerStatusCheck
	DownloadFormat
	XDG_CONFIG_HOME=/config/extended tidaler cfg download_base_path "$audioPath/incomplete" 2>&1 | tee -a "/config/logs/$logFileName"
	XDG_CONFIG_HOME=/config/extended tidaler cfg quality_audio "$tidalQuality" 2>&1 | tee -a "/config/logs/$logFileName"
	XDG_CONFIG_HOME=/config/extended tidaler cfg path_binary_ffmpeg "/usr/bin/ffmpeg" 2>&1 | tee -a "/config/logs/$logFileName"

	if ! ls "${tidalerConfigDir}"/*settings*.json "${tidalerConfigDir}"/*token*.json 1>/dev/null 2>&1; then
		TidalerStatusCheck
		log "TIDAL :: ERROR :: Loading client for required authentication, please authenticate, then exit the client..."
		NotifyWebhook "FatalError" "TIDAL requires authentication, please authenticate now (check logs)"
		TidalerStatusCheck
		if command -v script >/dev/null 2>&1; then
			script -q -c "PYTHONUNBUFFERED=1 XDG_CONFIG_HOME=/config/extended tidaler login" /dev/null
		else
			PYTHONUNBUFFERED=1 XDG_CONFIG_HOME=/config/extended tidaler login
		fi
	fi

	if [ ! -d /config/extended/cache/tidal ]; then
		mkdir -p /config/extended/cache/tidal
		chmod 777 /config/extended/cache/tidal
	fi
	
	if [ -d /config/extended/cache/tidal ]; then
		log "TIDAL :: Purging album list cache..."
		rm /config/extended/cache/tidal/*-albums.json &>/dev/null
	fi
	
	if [ ! -d "$audioPath/incomplete" ]; then
		mkdir -p "$audioPath"/incomplete
		chmod 777 "$audioPath"/incomplete
	else
		rm -rf "$audioPath"/incomplete/*
	fi
	
	TidalerStatusCheck
	
}

TidalerStatusCheck () {
	until false
	do
        running=no
        if ps aux | grep "tidaler" | grep -v "grep" | read; then 
            running=yes
            log "STATUS :: TIDALER :: BUSY :: Pausing/waiting for all active tidaler tasks to end..."
            sleep 2
            continue
        fi
		break
	done
}

TidalClientTest () { 
	log "TIDAL :: tidaler client setup verification..."
	i=0
	while [ $i -lt 3 ]; do
		i=$(( $i + 1 ))
  		TidalerStatusCheck
		XDG_CONFIG_HOME=/config/extended tidaler dl "https://tidal.com/browse/album/$tidalClientTestDownloadId" 2>&1 | tee -a "/config/logs/$logFileName"
		downloadCount=$(find "$audioPath"/incomplete -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" | wc -l)
		if [ $downloadCount -le 0 ]; then
			continue
		else
			break
		fi
	done
	tidalClientTest="unknown"
	if [ $downloadCount -le 0 ]; then
		rm -f "${tidalerConfigDir}"/*auth*.json "${tidalerConfigDir}"/*token*.json
		log "TIDAL :: ERROR :: Download failed"
		log "TIDAL :: ERROR :: You will need to re-authenticate on next script run..."
		log "TIDAL :: ERROR :: Exiting..."
		rm -rf "$audioPath"/incomplete/*
		NotifyWebhook "Error" "TIDAL not authenticated but configured"
  		tidalClientTest="failed"
    		log "Script sleeping for $audioScriptInterval..."
		sleep $audioScriptInterval
		exit
	else
		rm -rf "$audioPath"/incomplete/*
		log "TIDAL :: Successfully Verified"
  		tidalClientTest="success"
	fi
}

DownloadProcess () {

	# Required Input Data
	# $1 = Album ID to download from online Service
	# $2 = Download Client Type (DEEZER or TIDAL)
	# $3 = Album Year that matches Album ID Metadata
	# $4 = Album Title that matches Album ID Metadata
	# $5 = Expected Track Count

	# Create Required Directories	
	if [ ! -d "$audioPath/incomplete" ]; then
		mkdir -p "$audioPath"/incomplete
		chmod 777 "$audioPath"/incomplete
	else
		rm -rf "$audioPath"/incomplete/*
	fi
	
	if [ ! -d "$audioPath/complete" ]; then
		mkdir -p "$audioPath"/complete
		chmod 777 "$audioPath"/complete
	else
		rm -rf "$audioPath"/complete/*
	fi

	if [ ! -d "/config/extended/logs" ]; then
		mkdir -p /config/extended/logs
		chmod 777 /config/extended/logs
	fi

	if [ ! -d "/config/extended/logs/downloaded" ]; then
		mkdir -p /config/extended/logs/downloaded
		chmod 777 /config/extended/logs/downloaded
	fi

	if [ ! -d "/config/extended/logs/downloaded/deezer" ]; then
		mkdir -p /config/extended/logs/downloaded/deezer
		chmod 777 /config/extended/logs/downloaded/deezer
	fi

	if [ ! -d "/config/extended/logs/downloaded/tidal" ]; then
		mkdir -p /config/extended/logs/downloaded/tidal
		chmod 777 /config/extended/logs/downloaded/tidal
	fi

	if [ ! -d /config/extended/logs/downloaded/failed/deezer ]; then
		mkdir -p /config/extended/logs/downloaded/failed/deezer
		chmod 777 /config/extended/logs/downloaded/failed/deezer
	fi

	if [ ! -d /config/extended/logs/downloaded/failed/tidal ]; then
		mkdir -p /config/extended/logs/downloaded/failed/tidal
		chmod 777 /config/extended/logs/downloaded/failed/tidal
	fi

	if [ ! -d /config/extended/logs/downloaded/youtube ]; then
		mkdir -p /config/extended/logs/downloaded/youtube
		chmod 777 /config/extended/logs/downloaded/youtube
	fi

	if [ ! -d /config/extended/logs/downloaded/failed/youtube ]; then
		mkdir -p /config/extended/logs/downloaded/failed/youtube
		chmod 777 /config/extended/logs/downloaded/failed/youtube
	fi

	if [ ! -d "$importPath" ]; then
		mkdir -p "$importPath"
		chmod 777 "$importPath"
	fi

	AddDownloadClient

	downloadedAlbumTitleClean="$(echo "$4" | sed -e "s%[^[:alpha:][:digit:]._' ]% %g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')"
    	
	if find "$audioPath"/complete -type d -iname "$lidarrArtistNameSanitized-$downloadedAlbumTitleClean ($3)-*-$1-$2" | read; then
		log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: ERROR :: Previously Downloaded..."
		return
    fi

	# check for log file
	if [ "$2" == "DEEZER" ]; then
		if [ -f /config/extended/logs/downloaded/deezer/$1 ]; then
			log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: ERROR :: Previously Downloaded ($1)..."
			return
		fi
		if [ -f /config/extended/logs/downloaded/failed/deezer/$1 ]; then
			log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: ERROR :: Previously Attempted Download ($1)..."
			return
		fi
	fi

	# check for log file
	if [ "$2" == "TIDAL" ]; then
		if [ -f /config/extended/logs/downloaded/tidal/$1 ]; then
			log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: ERROR :: Previously Downloaded ($1)..."
			return
		fi
		if [ -f /config/extended/logs/downloaded/failed/tidal/$1 ]; then
			log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: ERROR :: Previously Attempted Download ($1)..."
			return
		fi
	fi

	# check for log file
	if [ "$2" == "YOUTUBE" ]; then
		if [ -f /config/extended/logs/downloaded/youtube/$1 ]; then
			log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: ERROR :: Previously Downloaded ($1)..."
			return
		fi
		if [ -f /config/extended/logs/downloaded/failed/youtube/$1 ]; then
			log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: ERROR :: Previously Attempted Download ($1)..."
			return
		fi
	fi



	downloadTry=0
	until false
	do	
		downloadTry=$(( $downloadTry + 1 ))
		if [ -f /temp-download ]; then
			rm /temp-download
			sleep 0.1
		fi
		touch /temp-download 
		sleep 0.1

		log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Download Attempt number $downloadTry"
		if [ "$2" == "DEEZER" ]; then

			if [ -z $arlToken ]; then
				DownloadClientFreyr $1
			else
				ProxyOn
				deemix -b $deemixQuality -p "$audioPath"/incomplete "https://www.deezer.com/album/$1" 2>&1 | tee -a "/config/logs/$logFileName"
				ProxyOff
			fi

			if [ -d "/tmp/deemix-imgs" ]; then
				rm -rf /tmp/deemix-imgs
			fi

			# Verify Client Works...
			clientTestDlCount=$(find "$audioPath"/incomplete/ -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" | wc -l)
			if [ $clientTestDlCount -le 0 ]; then
				# Add +1 to failed attempts
				deemixFail=$(( $deemixFail + 1))
			else
				# Reset for successful download
				deemixFail=0
			fi
			
			# If download failes X times, exit with error...
			if [ $deemixFail -eq $failedDownloadAttemptThreshold ]; then
				if [ -z $arlToken ]; then
    					rm -rf "$audioPath"/incomplete/*
					log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: All $failedDownloadAttemptThreshold Download Attempts failed, skipping..."
     				else
	    				DeezerClientTest
	       				if [ "$deezerClientTest" == "success" ]; then
		   				log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType ::  All $failedDownloadAttemptThreshold Download Attempts failed, skipping..."
	 					deemixFail=0
					fi
				fi
			fi
		fi

		if [ "$2" == "DEEZER" ]; then
  			if [ $deemixFail -eq $failedDownloadAttemptThreshold ]; then
				if [ -z $arlToken ]; then
					DownloadClientFreyr $1
				else
					ProxyOn
					deemix -b $deemixQuality -p "$audioPath"/incomplete "https://www.deezer.com/album/$1" 2>&1 | tee -a "/config/logs/$logFileName"
					ProxyOff
				fi
    			fi
       		fi

		if [ "$2" == "TIDAL" ]; then
			TidalerStatusCheck

			ProxyOn
			XDG_CONFIG_HOME=/config/extended tidaler cfg download_base_path "$audioPath/incomplete" 2>&1 | tee -a "/config/logs/$logFileName"
			XDG_CONFIG_HOME=/config/extended tidaler cfg quality_audio "$tidalQuality" 2>&1 | tee -a "/config/logs/$logFileName"
			XDG_CONFIG_HOME=/config/extended tidaler dl "https://tidal.com/browse/album/$1" 2>&1 | tee -a "/config/logs/$logFileName"
			ProxyOff

			# Verify Client Works...
			clientTestDlCount=$(find "$audioPath"/incomplete/ -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" | wc -l)
			if [ $clientTestDlCount -le 0 ]; then
				# Add +1 to failed attempts
				tidaldlFail=$(( $tidaldlFail + 1))
			else
				# Reset for successful download
				tidaldlFail=0
			fi
			
			# If download failes X times, exit with error...
			if [ $tidaldlFail -eq $failedDownloadAttemptThreshold ]; then
   				TidalClientTest
       				if [ "$tidalClientTest" == "success" ]; then
	   				log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: All $failedDownloadAttemptThreshold Download Attempts failed, skipping..."
				fi
			fi
		fi

		if [ "$2" == "YOUTUBE" ]; then
			DownloadClientYoutube "$1"

			# Verify Client Works... (YouTube audio is opus/m4a, not flac)
			clientTestDlCount=$(find "$audioPath"/incomplete/ -type f -regex ".*/.*\.\(flac\|opus\|ogg\|m4a\|mp3\)" | wc -l)
			if [ $clientTestDlCount -le 0 ]; then
				youtubedlFail=$(( $youtubedlFail + 1))
			else
				youtubedlFail=0
			fi

			# yt-dlp has no auth to verify -- just count failed attempts
			if [ $youtubedlFail -ge $failedDownloadAttemptThreshold ]; then
				log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: All $failedDownloadAttemptThreshold Download Attempts failed, skipping..."
				youtubedlFail=0
			fi
		fi

		find "$audioPath/incomplete" -type f -iname "*.flac" -newer "/temp-download" -print0 | while IFS= read -r -d '' file; do
			audioFlacVerification "$file"
			if [ "$verifiedFlacFile" == "0" ]; then
				log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Flac Verification :: $file :: Verified"
			else
				log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Flac Verification :: $file :: ERROR :: Failed Verification"
				rm "$file"
			fi
		done

		downloadCount=$(find "$audioPath"/incomplete/ -type f -regex ".*/.*\.\(flac\|opus\|ogg\|m4a\|mp3\)" | wc -l)
		if [ "$downloadCount" -ne "$5" ]; then
			log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: ERROR :: download failed, missing tracks..."
			completedVerification="false"
		else
			log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Success"
			completedVerification="true"
		fi

		if [ "$completedVerification" == "true" ]; then
			break
		elif [ "$downloadTry" == "2" ]; then
			if [ -d "$audioPath"/incomplete ]; then
				rm -rf "$audioPath"/incomplete/*
			fi
			break
		else
			log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Retry Download in 1 second fix errors..."
			sleep 1
		fi
	done   

	# Consolidate files to a single folder
	log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Consolidating files to single folder"
	find "$audioPath/incomplete" -type f -exec mv "{}" "$audioPath"/incomplete/ \; 2>/dev/null
	find $audioPath/incomplete/ -type d -mindepth 1 -maxdepth 1 -exec rm -rf {} \; 2>/dev/null

	downloadCount=$(find "$audioPath"/incomplete/ -type f -regex ".*/.*\.\(flac\|opus\|ogg\|m4a\|mp3\)" | wc -l)
	if [ "$downloadCount" -gt "0" ]; then
		# Check download for required quality (checks based on file extension)
		DownloadQualityCheck "$audioPath/incomplete" "$2"
	fi
	
	downloadCount=$(find "$audioPath"/incomplete/ -type f -regex ".*/.*\.\(flac\|opus\|ogg\|m4a\|mp3\)" | wc -l)
	if [ "$downloadCount" -ne "$5" ]; then
		log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: ERROR :: All download Attempts failed..."
		log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Logging $1 as failed download..."


		if [ "$2" == "DEEZER" ]; then
			touch /config/extended/logs/downloaded/failed/deezer/$1
		fi
		if [ "$2" == "TIDAL" ]; then
			touch /config/extended/logs/downloaded/failed/tidal/$1
		fi
		if [ "$2" == "YOUTUBE" ]; then
			touch /config/extended/logs/downloaded/failed/youtube/$1
		fi
		return
	fi

	# Log Completed Download
	log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Logging $1 as successfully downloaded..."
	if [ "$2" == "DEEZER" ]; then
		touch /config/extended/logs/downloaded/deezer/$1
	fi
	if [ "$2" == "TIDAL" ]; then
		touch /config/extended/logs/downloaded/tidal/$1
	fi
	if [ "$2" == "YOUTUBE" ]; then
		touch /config/extended/logs/downloaded/youtube/$1
	fi

	# Tag with beets
	if [ "$enableBeetsTagging" == "true" ]; then
		if [ -f /config/extended/beets-error ]; then
			rm /config/extended/beets-error
		fi
		log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Processing files with beets..."
		ProcessWithBeets "$audioPath/incomplete"
	fi

	# Embed Lyrics into Flac files
	find "$audioPath/incomplete" -type f -iname "*.flac" -print0 | while IFS= read -r -d '' file; do
		lrcFile="${file%.*}.lrc"
		if [ -f "$lrcFile" ]; then
			log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Embedding lyrics (lrc) into $file"
			metaflac --remove-tag=Lyrics "$file"
			metaflac --set-tag-from-file="Lyrics=$lrcFile" "$file"
		fi
	done
	
	if [ "$audioFormat" != "native" ]; then
		log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Converting Flac Audio to  ${audioFormat^^} ($audioBitrateText)"
		if [ "$audioFormat" == "opus" ]; then
			options="-c:a libopus -b:a ${audioBitrate}k -application audio -vbr off"
		    extension="opus"
		fi

		if [ "$audioFormat" == "mp3" ]; then
			options="-c:a libmp3lame -b:a ${audioBitrate}k"
			extension="mp3"
		fi

		if [ "$audioFormat" == "aac" ]; then
			options="-c:a aac -b:a ${audioBitrate}k -movflags faststart"
			extension="m4a"
		fi

		if [ "$audioFormat" == "alac" ]; then
			options="-c:a alac -movflags faststart"
			extension="m4a"
		fi

		find "$audioPath/incomplete" -type f -iname "*.flac" -print0 | while IFS= read -r -d '' audio; do
			file="${audio}"
			filename="$(basename "$audio")"
			foldername="$(dirname "$audio")"
        	filenamenoext="${filename%.*}"
			if [ "$audioFormat" == "opus" ]; then
				if opusenc --bitrate ${audioBitrate} --vbr --music "$file" "$foldername/${filenamenoext}.$extension"; then
					log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: $filename :: Conversion to $audioFormat ($audioBitrateText) successful"
					rm "$file"
				else
					log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: $filename :: ERROR :: Conversion Failed"
					rm "$foldername/${filenamenoext}.$extension"
				fi
				continue
			fi
			
			if ffmpeg -loglevel warning -hide_banner -nostats -i "$file" -n -vn $options "$foldername/${filenamenoext}.$extension" < /dev/null; then
				log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: $filename :: Conversion to $audioFormat ($audioBitrateText) successful"
				rm "$file"
			else
				log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: $filename :: ERROR :: Conversion Failed"
				rm "$foldername/${filenamenoext}.$extension"
			fi
		done

	fi
	
	if [ "$enableReplaygainTags" == "true" ]; then
		AddReplaygainTags "$audioPath/incomplete"
	else
		log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Replaygain Tagging Disabled (set enableReplaygainTags=true to enable...)"
	fi
	
	albumquality="$(find "$audioPath"/incomplete/ -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" | head -n 1 | egrep -i -E -o "\.{1}\w*$" | sed  's/\.//g')"
	downloadedAlbumFolder="${lidarrArtistNameSanitized}-${downloadedAlbumTitleClean:0:100} (${3})"

	find "$audioPath/incomplete" -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" -print0 | while IFS= read -r -d '' audio; do
        file="${audio}"
        filenoext="${file%.*}"
        filename="$(basename "$audio")"
        extension="${filename##*.}"
        filenamenoext="${filename%.*}"
        if [ ! -d "$audioPath/complete" ]; then
            mkdir -p "$audioPath"/complete
            chmod 777 "$audioPath"/complete
        fi
        mkdir -p "$audioPath/complete/$downloadedAlbumFolder"
        mv "$file" "$audioPath/complete/$downloadedAlbumFolder"/
        
    done
	chmod -R 777 "$audioPath"/complete

	mv "$audioPath/complete/$downloadedAlbumFolder" "$importPath"

	if [ -d "$importPath/$downloadedAlbumFolder" ]; then
		NotifyLidarrForImport "$importPath/$downloadedAlbumFolder"
		lidarrDownloadImportNotfication="true"
		LidarrTaskStatusCheck
	fi

	if [ -d "$audioPath/complete/$downloadedAlbumFolder" ]; then
		rm -rf "$audioPath"/incomplete/*
	fi
}

ProcessWithBeets () {
	# Input
	# $1 Download Folder to process
	if [ -f /config/extended/beets-library.blb ]; then
		rm /config/extended/beets-library.blb
		sleep 0.5
	fi
	if [ -f /config/extended/beets.log ]; then 
		rm /config/extended/beets.log
		sleep 0.5
	fi

	if [ -f "/config/beets-match" ]; then 
		rm "/config/beets-match"
		sleep 0.5
	fi
	touch "/config/beets-match"
	sleep 0.5

	beet -c /config/extended/beets-config.yaml -l /config/extended/beets-library.blb -d "$1" import -qC "$1"
	if [ $(find "$1" -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" -newer "/config/beets-match" | wc -l) -gt 0 ]; then
		log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: SUCCESS: Matched with beets!"
		log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: fixing track tags" 
		find "$audioPath/incomplete" -type f -iname "*.flac" -print0 | while IFS= read -r -d '' file; do
			getArtistCredit="$(ffprobe -loglevel 0 -print_format json -show_format -show_streams "$file" | jq -r ".format.tags.ARTIST_CREDIT" | sed "s/null//g" | sed "/^$/d")"
			# album artist
			metaflac --remove-tag=ALBUMARTIST "$file"
			metaflac --remove-tag=ALBUMARTIST_CREDIT "$file"
			metaflac --remove-tag=ALBUM_ARTIST "$file"
			metaflac --remove-tag="ALBUM ARTIST" "$file"
			# artist
			metaflac --remove-tag=ARTIST "$file"
			metaflac --remove-tag=ARTIST_CREDIT "$file"
			if [ ! -z "$getArtistCredit" ]; then
        		metaflac --set-tag=ARTIST="$getArtistCredit" "$file"
			else
				metaflac --set-tag=ARTIST="$lidarrArtistName" "$file"
			fi
			# sorts
			metaflac --remove-tag=ARTISTSORT "$file"
			metaflac --remove-tag=COMPOSERSORT "$file"
			metaflac --remove-tag=ALBUMARTISTSORT "$file"
			# lidarr
			metaflac --set-tag=ALBUMARTIST="$lidarrArtistName" "$file"
			# mbrainz
			metaflac --remove-tag=MUSICBRAINZ_ARTISTID "$file"
			metaflac --remove-tag=MUSICBRAINZ_ALBUMARTISTID "$file"
			metaflac --set-tag=MUSICBRAINZ_ARTISTID="$lidarrArtistForeignArtistId" "$file"
			metaflac --set-tag=MUSICBRAINZ_ALBUMARTISTID="$lidarrArtistForeignArtistId" "$file"
			log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: FIXED : $file"
		done
	else
		log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: ERROR :: Unable to match using beets to a musicbrainz release..."
		return
	fi	

	if [ -f "/config/beets-match" ]; then 
		rm "/config/beets-match"
		sleep 0.1
	fi

	# Get file metadata
	GetFile=$(find "$audioPath/incomplete" -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" | head -n1)
	extension="${GetFile##*.}"
	if [ "$extension" == "opus" ]; then
		matchedTags=$(ffprobe -hide_banner -loglevel fatal -show_error -show_format -show_streams -show_programs -show_chapters -show_private_data -print_format json "$GetFile" | jq -r ".streams[].tags")
	else
		matchedTags=$(ffprobe -hide_banner -loglevel fatal -show_error -show_format -show_streams -show_programs -show_chapters -show_private_data -print_format json "$GetFile" | jq -r ".format.tags")
	fi

	# Get Musicbrainz Release Group ID and Album Artist ID from tagged file
	if [ "$extension" == "flac" ] || [ "$extension" == "opus" ]; then
		matchedTagsAlbumReleaseGroupId="$(echo $matchedTags | jq -r ".MUSICBRAINZ_RELEASEGROUPID")"
		matchedTagsAlbumArtistId="$(echo $matchedTags | jq -r ".MUSICBRAINZ_ALBUMARTISTID")"
	elif [ "$extension" == "mp3" ] || [ "$extension" == "m4a" ]; then
		matchedTagsAlbumReleaseGroupId="$(echo $matchedTags | jq -r '."MusicBrainz Release Group Id"')"
		matchedLidarrAlbumArtistId="$(echo $matchedTags | jq -r '."MusicBrainz Ablum Artist Id"')"
	fi

	if [ ! -d "/config/extended/logs/downloaded/musicbrainz_matched" ]; then
		mkdir -p "/config/extended/logs/downloaded/musicbrainz_matched"
		chmod 777 "/config/extended/logs/downloaded/musicbrainz_matched"
	fi	

	if [ ! -f "/config/extended/logs/downloaded/musicbrainz_matched/$matchedTagsAlbumReleaseGroupId" ]; then
		log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Marking MusicBrainz Release Group ($matchedTagsAlbumReleaseGroupId) as successfully downloaded..."
		touch "/config/extended/logs/downloaded/musicbrainz_matched/$matchedTagsAlbumReleaseGroupId"

	fi
	
}

DownloadQualityCheck () {

	# YouTube audio is always lossy (opus/m4a). When a non-native output format
	# is configured the transcode step (further down in DownloadProcess) will
	# normalise it, so the pre-transcode check here would wrongly delete the
	# just-downloaded files -- skip it for YouTube in that case.
	if [ "$2" == "YOUTUBE" ] && [ "$audioFormat" != "native" ]; then
		log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Skipping pre-transcode quality check for YouTube (transcode step normalises format)..."
		return
	fi

	if [ "$requireQuality" == "true" ]; then
		log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Checking for unwanted files"

		if [ "$audioFormat" != "native" ]; then
			if find "$1" -type f -regex ".*/.*\.\(opus\|m4a\|mp3\)"| read; then
				log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Unwanted files found!"
				log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Performing cleanup..."
				rm "$1"/*
			else
				log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: No unwanted files found!"
			fi
		fi
		if [ "$audioFormat" == "native" ]; then
			if [ "$audioBitrate" == "master" ]; then
				if find "$1" -type f -regex ".*/.*\.\(opus\|m4a\|mp3\)"| read; then
					log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Unwanted files found!"
					log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Performing cleanup..."
					rm "$1"/*
				else
					log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: No unwanted files found!"
				fi
			elif [ "$audioBitrate" == "lossless" ]; then
				if find "$1" -type f -regex ".*/.*\.\(opus\|m4a\|mp3\)"| read; then
					log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Unwanted files found!"
					log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Performing cleanup..."
					rm "$1"/*
				else
					log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: No unwanted files found!"
				fi
			elif [ "$2" == "DEEZER" ]; then
				if find "$1" -type f -regex ".*/.*\.\(opus\|m4a\|flac\)"| read; then
					log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Unwanted files found!"
					log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Performing cleanup..."
					rm "$1"/*
				else
					log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: No unwanted files found!"
				fi
			elif [ "$2" == "TIDAL" ]; then
				if find "$1" -type f -regex ".*/.*\.\(opus\|flac\|mp3\)"| read; then
					log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Unwanted files found!"
					log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Performing cleanup..."
					rm "$1"/*
				else
					log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: No unwanted files found!"
				fi
			elif [ "$2" == "YOUTUBE" ]; then
				# native + high/low: keep the lossy YouTube audio, only reject flac
				if find "$1" -type f -regex ".*/.*\.\(flac\)"| read; then
					log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Unwanted files found!"
					log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Performing cleanup..."
					rm "$1"/*
				else
					log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: No unwanted files found!"
				fi
			fi
		fi
	else
		log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType ::  Skipping download quality check... (enable by setting: requireQuality=true)"
	fi
}

AddReplaygainTags () {
	# Input Data
	# $1 Folder path to scan and add tags
	log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Adding Replaygain Tags using r128gain"
	r128gain -r -c 1 -a "$1" &>/dev/null
}

NotifyLidarrForImport () {
	LidarrProcessIt=$(curl -s "$arrUrl/api/v1/command" --header "X-Api-Key:"${arrApiKey} -H "Content-Type: application/json" --data "{\"name\":\"DownloadedAlbumsScan\", \"path\":\"$1\"}")
	log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: LIDARR IMPORT NOTIFICATION SENT! :: $1"
}

DeemixClientSetup () {
	log "DEEZER :: Verifying deemix configuration"
	if [ ! -z "$arlToken" ]; then
		arlToken="$(echo $arlToken | sed -e "s%[^[:alpha:][:digit:]]%%g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')"
		# Create directories
		mkdir -p /config/xdg/deemix
		if [ -f "/config/xdg/deemix/.arl" ]; then
			rm "/config/xdg/deemix/.arl"
		fi
		if [ ! -f "/config/xdg/deemix/.arl" ]; then
			echo -n "$arlToken" > "/config/xdg/deemix/.arl"
		fi
		log "DEEZER :: ARL Token: Configured"
	else
		log "DEEZER :: ERROR :: arlToken setting invalid, currently set to: $arlToken"
	fi
	
	if [ -f "/config/xdg/deemix/config.json" ]; then
		rm /config/xdg/deemix/config.json
	fi
	
	if [ -f "/config/extended/deemix_config.json" ]; then
		log "DEEZER :: Configuring deemix client"
		cp /config/extended/deemix_config.json /config/xdg/deemix/config.json
		chmod 777 /config/xdg/deemix/config.json
	fi
	
	if [ -d /config/extended/cache/deezer ]; then
		log "DEEZER :: Purging album list cache..."
		rm /config/extended/cache/deezer/*-albums.json &>/dev/null
	fi
	
	if [ ! -d "$audioPath/incomplete" ]; then
		mkdir -p "$audioPath"/incomplete
		chmod 777 "$audioPath"/incomplete
	else
		rm -rf "$audioPath"/incomplete/*
	fi

	#log "DEEZER :: Upgrade deemix to the latest..."
	#pip install deemix --upgrade &>/dev/null

}

DeezerClientTest () {
	log "DEEZER :: deemix client setup verification..."

	deemix -b 128 -p $audioPath/incomplete "https://www.deezer.com/album/$deezerClientTestDownloadId"  2>&1 | tee -a "/config/logs/$logFileName"
	if [ -d "/tmp/deemix-imgs" ]; then
		rm -rf /tmp/deemix-imgs
	fi
 	deezerClientTest="unknown"
	downloadCount=$(find $audioPath/incomplete/ -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" | wc -l)
	if [ $downloadCount -le 0 ]; then
		log "DEEZER :: ERROR :: Download failed"
		log "DEEZER :: ERROR :: Please review log for errors in client"
		log "DEEZER :: ERROR :: Try updating your ARL Token to possibly resolve the issue..."
		log "DEEZER :: ERROR :: Exiting..."
		rm -rf $audioPath/incomplete/*
		NotifyWebhook "Error" "DEEZER not authenticated but configured"
  		deezerClientTest="fail"
    		log "Script sleeping for $audioScriptInterval..."
		sleep $audioScriptInterval
		exit
	else
		rm -rf $audioPath/incomplete/*
		log "DEEZER :: Successfully Verified"
  		deezerClientTest="success"
	fi

}

LidarrRootFolderCheck () {
	if curl -s "$arrUrl/api/v1/rootFolder" -H "X-Api-Key: ${arrApiKey}" | sed '1q' | grep "\[\]" | read; then
		log "ERROR :: No root folder found"
		log "ERROR :: Configure root folder in Lidarr to continue..."
		log "ERROR :: Exiting..."
		NotifyWebhook "FatalError" "No root folder found"
  		log "Script sleeping for $audioScriptInterval..."
		sleep $audioScriptInterval
		exit
	fi
}

GetMissingCutOffList () {
    
	# Remove previous search missing/cutoff list
	if [ -d  /config/extended/cache/lidarr/list ]; then
		rm -rf  /config/extended/cache/lidarr/list
		sleep 0.1
	fi

	# Create list folder if does not exist
	mkdir -p /config/extended/cache/lidarr/list

	# Create notfound log folder if does not exist
	if [ ! -d /config/extended/logs/notfound ]; then
		mkdir -p /config/extended/logs/notfound
		chmod 777 /config/extended/logs/notfound
	fi
	
	# Configure searchSort preferences based on settings
	if [ "$searchSort" == "date" ]; then
		searchOrder="releaseDate"
		searchDirection="descending"
	fi
	
	if [ "$searchSort" == "album" ]; then
		searchOrder="albumType"
		searchDirection="ascending"
	fi

	lidarrMissingTotalRecords=$(wget --timeout=0 -q -O - "$arrUrl/api/v1/wanted/missing?page=1&pagesize=1&sortKey=$searchOrder&sortDirection=$searchDirection&apikey=${arrApiKey}" | jq -r .totalRecords)

	log "FINDING MISSING ALBUMS :: sorted by $searchSort"

	amountPerPull=1000
	page=0
	log "$lidarrMissingTotalRecords Missing Albums Found!"
	log "Getting Missing Album IDs"
	if [ $lidarrMissingTotalRecords -ge 1 ]; then
		offsetcount=$(( $lidarrMissingTotalRecords / $amountPerPull ))
		for ((i=0;i<=$offsetcount;i++)); do
			page=$(( $i + 1 ))
			offset=$(( $i * $amountPerPull ))
			dlnumber=$(( $offset + $amountPerPull ))
			if [ "$dlnumber" -gt "$lidarrMissingTotalRecords" ]; then
				dlnumber="$lidarrMissingTotalRecords"
			fi
			log "$page :: missing :: Downloading page $page... ($offset - $dlnumber of $lidarrMissingTotalRecords Results)"
      wget --timeout=0 -q -O - "$arrUrl/api/v1/wanted/missing?page=$page&pagesize=$amountPerPull&sortKey=$searchOrder&sortDirection=$searchDirection&apikey=${arrApiKey}" | jq -r '.records[].id' | sort > /config/extended/cache/tocheck.txt
			log "$page :: missing :: Filtering out albums already not found on ALL configured clients (${dlClients[*]})"
			BuildNotFoundExhaustedList /config/extended/cache/notfound.txt

			for lidarrRecordId in $(comm -13 /config/extended/cache/notfound.txt /config/extended/cache/tocheck.txt); do
				touch "/config/extended/cache/lidarr/list/${lidarrRecordId}-missing"
			done
			rm /config/extended/cache/notfound.txt /config/extended/cache/tocheck.txt
			
			lidarrMissingRecords=$(ls /config/extended/cache/lidarr/list 2>/dev/null | wc -l)
			log "$page :: missing :: ${lidarrMissingRecords} albums found to process!"
			wantedListAlbumTotal=$lidarrMissingRecords

			if [ ${lidarrMissingRecords} -gt 0 ]; then
				log "$page :: missing :: Searching for $wantedListAlbumTotal items"
				SearchProcess
				rm /config/extended/cache/lidarr/list/*-missing
			fi
		done
	fi
	

	# Get cutoff album list
	lidarrCutoffTotalRecords=$(wget --timeout=0 -q -O - "$arrUrl/api/v1/wanted/cutoff?page=1&pagesize=1&sortKey=$searchOrder&sortDirection=$searchDirection&apikey=${arrApiKey}" | jq -r .totalRecords)
	log "FINDING CUTOFF ALBUMS sorted by $searchSort"
	log "$lidarrCutoffTotalRecords CutOff Albums Found Found!"
	log "Getting CutOff Album IDs"
	page=0
	if [ $lidarrCutoffTotalRecords -ge 1 ]; then
		offsetcount=$(( $lidarrCutoffTotalRecords / $amountPerPull ))
		for ((i=0;i<=$offsetcount;i++)); do
			page=$(( $i + 1 ))
			offset=$(( $i * $amountPerPull ))
			dlnumber=$(( $offset + $amountPerPull ))
			if [ "$dlnumber" -gt "$lidarrCutoffTotalRecords" ]; then
				dlnumber="$lidarrCutoffTotalRecords"
			fi

			log "$page :: cutoff :: Downloading page $page... ($offset - $dlnumber of $lidarrCutoffTotalRecords Results)"
			# lidarrRecords=$(wget --timeout=0 -q -O - "$arrUrl/api/v1/wanted/cutoff?page=$page&pagesize=$amountPerPull&sortKey=$searchOrder&sortDirection=$searchDirection&apikey=${arrApiKey}" | jq -r '.records[].id')
      wget --timeout=0 -q -O - "$arrUrl/api/v1/wanted/cutoff?page=$page&pagesize=$amountPerPull&sortKey=$searchOrder&sortDirection=$searchDirection&apikey=${arrApiKey}" | jq -r '.records[].id' | sort > /config/extended/cache/tocheck.txt

			log "$page :: cutoff :: Filtering out albums already not found on ALL configured clients (${dlClients[*]})"
			BuildNotFoundExhaustedList /config/extended/cache/notfound.txt

			for lidarrRecordId in $(comm -13 /config/extended/cache/notfound.txt /config/extended/cache/tocheck.txt); do
				touch /config/extended/cache/lidarr/list/${lidarrRecordId}-cutoff
			done
			rm /config/extended/cache/notfound.txt /config/extended/cache/tocheck.txt

			lidarrCutoffRecords=$(ls /config/extended/cache/lidarr/list/*-cutoff 2>/dev/null | wc -l)
			log "$page :: cutoff :: ${lidarrCutoffRecords} albums found to process!"
			wantedListAlbumTotal=$lidarrCutoffRecords

			if [ ${lidarrCutoffRecords} -gt 0 ]; then
				log "$page :: cutoff :: Searching for $wantedListAlbumTotal items"
				SearchProcess
				rm /config/extended/cache/lidarr/list/*-cutoff
			fi

		done
	fi    
}

SearchProcess () {

	if [ "$wantedListAlbumTotal" == "0" ]; then
		log "No items to find, end"
		return
	fi

	processNumber=0
	for lidarrMissingId in $(ls -tr /config/extended/cache/lidarr/list); do
		processNumber=$(( $processNumber + 1 ))
		wantedAlbumId=$(echo $lidarrMissingId | sed -e "s%[^[:digit:]]%%g")
		checkLidarrAlbumId=$wantedAlbumId
		wantedAlbumListSource=$(echo $lidarrMissingId | sed -e "s%[^[:alpha:]]%%g")
		lidarrAlbumData="$(curl -s "$arrUrl/api/v1/album/$wantedAlbumId?apikey=${arrApiKey}")"
		lidarrArtistData=$(echo "${lidarrAlbumData}" | jq -r ".artist")
		lidarrArtistName=$(echo "${lidarrArtistData}" | jq -r ".artistName")
		lidarrArtistForeignArtistId=$(echo "${lidarrArtistData}" | jq -r ".foreignArtistId")
		lidarrAlbumType=$(echo "$lidarrAlbumData" | jq -r ".albumType")
		lidarrAlbumTitle=$(echo "$lidarrAlbumData" | jq -r ".title")
		lidarrAlbumForeignAlbumId=$(echo "$lidarrAlbumData" | jq -r ".foreignAlbumId")
		
		LidarrTaskStatusCheck
				
		notFoundBase="/config/extended/logs/notfound/$wantedAlbumId--$lidarrArtistForeignArtistId--$lidarrAlbumForeignAlbumId"

		# Migrate any legacy (pre-2.49) suffix-less marker for this album
		if [ -f "$notFoundBase" ]; then
			for _c in deezer tidal; do
				touch "$notFoundBase--$_c"
				chmod 777 "$notFoundBase--$_c" 2>/dev/null
			done
			rm -f "$notFoundBase"
		fi

		# Which configured clients still need to try this album?
		albumClients=()
		for _c in "${dlClients[@]}"; do
			[ -f "$notFoundBase--$_c" ] && continue
			albumClients+=("$_c")
		done
		if [ ${#albumClients[@]} -eq 0 ]; then
			log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Previously Not Found on all configured clients (${dlClients[*]}), skipping..."
			continue
		fi

		if [ "$enableVideoScript" == "true" ]; then
			# Skip Video Check for Various Artists album searches because videos are not supported...
			if [ "$lidarrArtistForeignArtistId" != "89ad4ac3-39f7-470e-963a-56509c546377" ]; then
				if [ -d /config/extended/logs/video/complete ]; then
					if [ ! -f "/config/extended/logs/video/complete/$lidarrArtistForeignArtistId" ]; then
						log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrAlbumType :: $wantedAlbumListSource :: $lidarrArtistName :: $lidarrAlbumTitle :: Skipping until all videos are processed for the artist..."
						continue
					fi
				else
					log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrAlbumType :: $wantedAlbumListSource :: $lidarrArtistName :: $lidarrAlbumTitle :: Skipping until all videos are processed for the artist..."
					continue
				fi
			fi
		fi
		
		if [ -f "/config/extended/logs/downloaded/notfound/$lidarrAlbumForeignAlbumId" ]; then
			log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrAlbumTitle :: $lidarrAlbumType :: Previously Not Found (metadata match), skipping..."
			rm "/config/extended/logs/downloaded/notfound/$lidarrAlbumForeignAlbumId"
			# MusicBrainz-level "no match" -> mark every configured client exhausted
			for _c in "${dlClients[@]}"; do
				touch "$notFoundBase--$_c"
				chmod 777 "$notFoundBase--$_c" 2>/dev/null
			done
			continue
		fi

		
		lidarrAlbumTitleClean=$(echo "$lidarrAlbumTitle" | sed -e "s%[^[:alpha:][:digit:]]%%g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')
		lidarrAlbumTitleCleanSpaces=$(echo "$lidarrAlbumTitle" | sed -e "s%[^[:alpha:][:digit:]]% %g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')
		lidarrAlbumReleases=$(echo "$lidarrAlbumData" | jq -r ".releases")
		#echo $lidarrAlbumData | jq -r 
		lidarrAlbumWordCount=$(echo $lidarrAlbumTitle | wc -w)
		#echo $lidarrAlbumReleases | jq -r 
		lidarrArtistData=$(echo "${lidarrAlbumData}" | jq -r ".artist")
		lidarrArtistId=$(echo "${lidarrArtistData}" | jq -r ".artistMetadataId")
		lidarrArtistPath="$(echo "${lidarrArtistData}" | jq -r " .path")"
		lidarrArtistFolder="$(basename "${lidarrArtistPath}")"
		lidarrArtistName=$(echo "${lidarrArtistData}" | jq -r ".artistName")
		lidarrArtistNameSanitized="$(basename "${lidarrArtistPath}" | sed 's% (.*)$%%g' | sed 's/-/ /g')"
		lidarrArtistNameSearchSanitized="$(echo "$lidarrArtistName" | sed -e "s%[^[:alpha:][:digit:]]% %g" -e "s/  */ /g")"
		albumArtistNameSearch="$(jq -R -r @uri <<<"${lidarrArtistNameSearchSanitized}")"
		lidarrArtistForeignArtistId=$(echo "${lidarrArtistData}" | jq -r ".foreignArtistId")
		tidalArtistUrl=$(echo "${lidarrArtistData}" | jq -r ".links | .[] | select(.name==\"tidal\") | .url")
		tidalArtistIds="$(echo "$tidalArtistUrl" | grep -o '[[:digit:]]*' | sort -u)"
		deezerArtistUrl=$(echo "${lidarrArtistData}" | jq -r ".links | .[] | select(.name==\"deezer\") | .url")
		lidarrAlbumReleaseIds=$(echo "$lidarrAlbumData" | jq -r ".releases | sort_by(.trackCount) | reverse | .[].id")
		lidarrAlbumReleasesMinTrackCount=$(echo "$lidarrAlbumData" | jq -r ".releases[].trackCount" | sort -n | head -n1)
		lidarrAlbumReleasesMaxTrackCount=$(echo "$lidarrAlbumData" | jq -r ".releases[].trackCount" | sort -n -r | head -n1)
		lidarrAlbumReleaseDate=$(echo "$lidarrAlbumData" | jq -r .releaseDate)
		lidarrAlbumReleaseDate=${lidarrAlbumReleaseDate:0:10}
		lidarrAlbumReleaseDateClean="$(echo $lidarrAlbumReleaseDate | sed -e "s%[^[:digit:]]%%g")"
		lidarrAlbumReleaseYear="${lidarrAlbumReleaseDate:0:4}"
		
		currentDate="$(date "+%F")"
		currentDateClean="$(echo "$currentDate" | sed -e "s%[^[:digit:]]%%g")"

		

		if [[ ${currentDateClean} -ge ${lidarrAlbumReleaseDateClean} ]]; then
			skipNotFoundLogCreation="false"
			releaseDateComparisonInDays=$(( ${currentDateClean} - ${lidarrAlbumReleaseDateClean} ))
			log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Starting Search..."
			if [ $releaseDateComparisonInDays -lt 8 ]; then
				skipNotFoundLogCreation="true"
			fi
		else
			log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Album ($lidarrAlbumReleaseDate) has not been released, skipping..."
			continue
		fi

		# Only try clients that are configured AND haven't already failed this
		# album (per-client notfound marker). albumClients[] was built above.
		skipDeezer=true
		skipTidal=true
		skipYoutube=true
		for _c in "${albumClients[@]}"; do
			case "$_c" in
				deezer)  skipDeezer=false ;;
				tidal)   skipTidal=false ;;
				youtube) skipYoutube=false ;;
			esac
		done
		if [ "$youtubeClientEnabled" != "true" ]; then
			skipYoutube=true
		fi

		if [ "$skipDeezer" == "false" ]; then

			if [ -z "$deezerArtistUrl" ]; then 
				log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: DEEZER :: ERROR :: musicbrainz id: $lidarrArtistForeignArtistId is missing Deezer link, see: \"/config/logs/deezer-artist-id-not-found.txt\" for more detail..."
				touch "/config/logs/deezer-artist-id-not-found.txt"
				if cat "/config/logs/deezer-artist-id-not-found.txt" | grep "https://musicbrainz.org/artist/$lidarrArtistForeignArtistId/edit" | read; then
					sleep 0.01
				else
					echo "Update Musicbrainz Relationship Page: https://musicbrainz.org/artist/$lidarrArtistForeignArtistId/edit for \"${lidarrArtistName}\" with Deezer Artist Link" >> "/config/logs/deezer-artist-id-not-found.txt"
					chmod 777 "/config/logs/deezer-artist-id-not-found.txt"
					NotifyWebhook "ArtistError" "Update Musicbrainz Relationship Page: <https://musicbrainz.org/artist/${lidarrArtistForeignArtistId}/edit> for ${lidarrArtistName} with Deezer Artist Link"
				fi
				skipDeezer=true
			fi
			deezerArtistIds=($(echo "$deezerArtistUrl" | grep -o '[[:digit:]]*' | sort -u))
		fi

        if [ "$skipTidal" == "false" ]; then

			if [ -z "$tidalArtistUrl" ]; then 
				log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: TIDAL :: ERROR :: musicbrainz id: $lidarrArtistForeignArtistId is missing Tidal link, see: \"/config/logs/tidal-artist-id-not-found.txt\" for more detail..."
				touch "/config/logs/tidal-artist-id-not-found.txt" 
				if cat "/config/logs/tidal-artist-id-not-found.txt" | grep "https://musicbrainz.org/artist/$lidarrArtistForeignArtistId/edit" | read; then
					sleep 0.01
				else
					echo "Update Musicbrainz Relationship Page: https://musicbrainz.org/artist/$lidarrArtistForeignArtistId/edit for \"${lidarrArtistName}\" with Tidal Artist Link" >> "/config/logs/tidal-artist-id-not-found.txt"
					chmod 777 "/config/logs/tidal-artist-id-not-found.txt"
					NotifyWebhook "ArtistError" "Update Musicbrainz Relationship Page: <https://musicbrainz.org/artist/${lidarrArtistForeignArtistId}/edit> for ${lidarrArtistName} with Tidal Artist Link"
				fi
				skipTidal=true
			fi
		fi

		# Begin cosolidated search process
		if [ "$audioLyricType" == "both" ]; then
			endLoop="2"
		else
			endLoop="1"
		fi


		# Get Release Titles & Disambiguation
		if [ -f /temp-release-list ]; then
			rm /temp-release-list 
		fi
		for releaseId in $(echo "$lidarrAlbumReleaseIds"); do
			releaseTitle=$(echo "$lidarrAlbumData" | jq -r ".releases[] | select(.id==$releaseId) | .title")
			releaseDisambiguation=$(echo "$lidarrAlbumData" | jq -r ".releases[] | select(.id==$releaseId) | .disambiguation")
			if [ -z "$releaseDisambiguation" ]; then
				releaseDisambiguation=""
			else
				releaseDisambiguation=" ($releaseDisambiguation)" 
			fi
			echo "${releaseTitle}${releaseDisambiguation}" >> /temp-release-list 
		done
  		echo "$lidarrAlbumTitle" >> /temp-release-list 

		# Get Release Titles
		OLDIFS="$IFS"
		IFS=$'\n'
		if [ "$preferSpecialEditions" == "true" ]; then
		  lidarrReleaseTitles=$(cat /temp-release-list | awk '{ print length, $0 }' | sort -u -n -s -r | cut -d" " -f2-)
	    else
		  lidarrReleaseTitles=$(cat /temp-release-list | awk '{ print length, $0 }' | sort -u -n -s | cut -d" " -f2-)
		fi
		lidarrReleaseTitles=($(echo "$lidarrReleaseTitles"))
		IFS="$OLDIFS"

		loopCount=0
		until false
		do
			
			loopCount=$(( $loopCount + 1 ))
			if [ "$loopCount" == "1" ]; then
				# First loop is either explicit or clean depending on script settings
				if [ "$audioLyricType" == "both" ] || [ "$audioLyricType" == "explicit" ]; then
					lyricFilter="true"
				else
					lyricFilter="false"
				fi
			else
				# 2nd loop is always clean
				lyricFilter="false"
			fi
			
			lidarrDownloadImportNotfication="false"
			releaseProcessCount=0
			for title in ${!lidarrReleaseTitles[@]}; do
				releaseProcessCount=$(( $releaseProcessCount + 1))
				lidarrReleaseTitle="${lidarrReleaseTitles[$title]}"
				lidarrAlbumReleaseTitleClean=$(echo "$lidarrReleaseTitle" | sed -e "s%[^[:alpha:][:digit:]]%%g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')
    			lidarrAlbumReleaseTitleClean="${lidarrAlbumReleaseTitleClean:0:130}"
				lidarrAlbumReleaseTitleSearchClean="$(echo "$lidarrReleaseTitle" | sed -e "s%[^[:alpha:][:digit:]]% %g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')"
				lidarrAlbumReleaseTitleFirstWord="$(echo "$lidarrReleaseTitle"  | awk '{ print $1 }')"
				lidarrAlbumReleaseTitleFirstWord="${lidarrAlbumReleaseTitleFirstWord:0:3}"
				albumTitleSearch="$(jq -R -r @uri <<<"${lidarrAlbumReleaseTitleSearchClean}")"
				#echo "Debugging :: $loopCount :: $releaseProcessCount :: $lidarrArtistForeignArtistId :: $lidarrReleaseTitle :: $lidarrAlbumReleasesMinTrackCount-$lidarrAlbumReleasesMaxTrackCount :: $lidarrAlbumReleaseTitleFirstWord :: $albumArtistNameSearch :: $albumTitleSearch"


    				if echo "$lidarrAlbumTitle" | grep -i "instrumental" | read; then
					sleep 0.01
    				else
					# ignore instrumental releases
	    				if [ "$ignoreInstrumentalRelease" == "true" ]; then
		    				if echo "$lidarrReleaseTitle" | grep -i "instrumental" | read; then
							log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Instrumental Release Found, Skipping..."
		     					continue
		 				fi
	      				fi
				fi

				# Skip Various Artists album search that is not supported...
				if [ "$lidarrArtistForeignArtistId" != "89ad4ac3-39f7-470e-963a-56509c546377" ]; then

					#log "1 : $lidarrDownloadImportNotfication"				
					
					# Tidal Artist search
					if [ "$lidarrDownloadImportNotfication" == "false" ]; then
						if [ "$skipTidal" == "false" ]; then
							for tidalArtistId in $(echo $tidalArtistIds); do
								ArtistTidalSearch "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal" "$tidalArtistId" "$lyricFilter"
								sleep 0.01
							done
						fi
					fi

					#log "2 : $lidarrDownloadImportNotfication"

					# Deezer artist search
					if [ "$lidarrDownloadImportNotfication" == "false" ]; then
						if [ "$skipDeezer" == "false" ]; then
							for dId in ${!deezerArtistIds[@]}; do
								deezerArtistId="${deezerArtistIds[$dId]}"
								ArtistDeezerSearch "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal" "$deezerArtistId" "$lyricFilter"
								sleep 0.01
							done
						fi
					fi
				fi

				#log "3 : $lidarrDownloadImportNotfication"
				# Tidal fuzzy search
				if [ "$lidarrDownloadImportNotfication" == "false" ]; then
					if [ "$skipTidal" == "false" ]; then
						FuzzyTidalSearch "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal" "$lyricFilter"
						sleep 0.01
					fi
				fi

				#log "4 : $lidarrDownloadImportNotfication"
				# Deezer fuzzy search
				if [ "$lidarrDownloadImportNotfication" == "false" ]; then
					if [ "$skipDeezer" == "false" ]; then
						FuzzyDeezerSearch "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal" "$lyricFilter"
						sleep 0.01
					fi
				fi

				#log "5 : $lidarrDownloadImportNotfication"
				# YouTube (YouTube Music) search -- one pass only, no lyric filter
				if [ "$lidarrDownloadImportNotfication" == "false" ] && [ "$loopCount" == "1" ]; then
					if [ "$skipYoutube" == "false" ]; then
						YoutubeSearch "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal"
						sleep 0.01
					fi
				fi

				# End search if lidarr was successfully notified for import
				if [ "$lidarrDownloadImportNotfication" == "true" ]; then
					break
				fi
			done
				
			# End search if lidarr was successfully notified for import
			if [ "$lidarrDownloadImportNotfication" == "true" ]; then
				break
			fi

			# Break after all operations are complete
			if [ "$loopCount" == "$endLoop" ]; then
				log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Album Not found"
				if [ "$skipNotFoundLogCreation" == "false" ]; then
					log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Marking album as notfound for client(s): ${albumClients[*]}"
					for _c in "${albumClients[@]}"; do
						if [ ! -f "$notFoundBase--$_c" ]; then
							touch "$notFoundBase--$_c"
							chmod 777 "$notFoundBase--$_c" 2>/dev/null
						fi
					done
				else
					log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Skip marking album as not found because it's a new release for 7 days..."
				fi
				break
			fi
		done

		log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Search Complete..." 
	done
}

GetDeezerAlbumInfo () {
	until false
	do
		log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: Getting Album info..."
		if [ ! -f "/config/extended/cache/deezer/$1.json" ]; then
			curl -s "https://api.deezer.com/album/$1" -o "/config/extended/cache/deezer/$1.json"
			sleep $sleepTimer
		fi
		if [ -f "/config/extended/cache/deezer/$1.json" ]; then
			if jq -e . >/dev/null 2>&1 <<<"$(cat /config/extended/cache/deezer/$1.json)"; then
				log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: Album info downloaded and verified..."
				chmod 777 /config/extended/cache/deezer/$1.json
				albumInfoVerified=true
				break
			else
				log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: Error getting album information"
				if [ -f "/config/extended/cache/deezer/$1.json" ]; then
					rm "/config/extended/cache/deezer/$1.json"
				fi
				log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: Retrying..."
			fi
		else
			log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: ERROR :: Download Failed"
		fi
	done

}

ArtistDeezerSearch () {
	# Required Inputs
	# $1 Process ID
	# $2 Deezer Artist ID
	# $3 Lyric Type (true or false) - false == Clean, true == Explicit

	# Get deezer artist album list
	if [ ! -d /config/extended/cache/deezer ]; then
		mkdir -p /config/extended/cache/deezer
	fi
	if [ ! -f "/config/extended/cache/deezer/$2-albums.json" ]; then
		getDeezerArtistAlbums=$(curl -s "https://api.deezer.com/artist/$2/albums?limit=1000" > "/config/extended/cache/deezer/$2-albums.json")
		sleep $sleepTimer
		getDeezerArtistAlbumsCount="$(cat "/config/extended/cache/deezer/$2-albums.json" | jq -r .total)"
	fi
	
	if [ "$getDeezerArtistAlbumsCount" == "0" ]; then
		return
	fi

	if [ "$3" == "true" ]; then
		type="Explicit"
	else
		type="Clean"
	fi
	
	log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Artist Search :: Deezer :: $type :: $lidarrReleaseTitle :: Searching $2... (Track Count: $lidarrAlbumReleasesMinTrackCount-$lidarrAlbumReleasesMaxTrackCount)..."		
	log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Artist Search :: Deezer :: $type :: $lidarrReleaseTitle :: Filtering results by lyric type..."
	deezerArtistAlbumsData=$(cat "/config/extended/cache/deezer/$2-albums.json" | jq -r .data[])
	deezerArtistAlbumsIds=$(echo "${deezerArtistAlbumsData}" | jq -r "select(.explicit_lyrics=="$3") | .id")

	resultsCount=$(echo "$deezerArtistAlbumsIds" | wc -l)
	log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Artist Search :: Deezer :: $type :: $lidarrReleaseTitle :: $resultsCount search results found"
	for deezerAlbumID in $(echo "$deezerArtistAlbumsIds"); do
		deezerAlbumData="$(echo "$deezerArtistAlbumsData" | jq -r "select(.id==$deezerAlbumID)")"
		deezerAlbumTitle="$(echo "$deezerAlbumData" | jq -r ".title")"
		deezerAlbumTitleClean="$(echo ${deezerAlbumTitle} | sed -e "s%[^[:alpha:][:digit:]]%%g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')"
  		deezerAlbumTitleClean="${deezerAlbumTitleClean:0:130}"		
		GetDeezerAlbumInfo "$deezerAlbumID"
		deezerAlbumData="$(cat "/config/extended/cache/deezer/$deezerAlbumID.json")"
		deezerAlbumTrackCount="$(echo "$deezerAlbumData" | jq -r .nb_tracks)"
		deezerAlbumExplicitLyrics="$(echo "$deezerAlbumData" | jq -r .explicit_lyrics)"								
		downloadedReleaseDate="$(echo "$deezerAlbumData" | jq -r .release_date)"
		downloadedReleaseYear="${downloadedReleaseDate:0:4}"

		# Reject release if greater than the max track count
		if [ "$deezerAlbumTrackCount" -gt "$lidarrAlbumReleasesMaxTrackCount" ]; then
			continue
		fi

		# Reject release if less than the min track count
		if [ "$deezerAlbumTrackCount" -lt "$lidarrAlbumReleasesMinTrackCount" ]; then
			continue
		fi
		
		log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Artist Search :: Deezer :: $type :: $lidarrReleaseTitle :: $lidarrAlbumReleaseTitleClean vs $deezerAlbumTitleClean :: Checking for Match..."
		log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Artist Search :: Deezer :: $type :: $lidarrReleaseTitle :: $lidarrAlbumReleaseTitleClean vs $deezerAlbumTitleClean :: Calculating Damerau-Levenshtein distance..."
		diff=$(python -c "from pyxdameraulevenshtein import damerau_levenshtein_distance; print(damerau_levenshtein_distance(\"${lidarrAlbumReleaseTitleClean,,}\", \"${deezerAlbumTitleClean,,}\"))" 2>/dev/null)
		if [ "$diff" -le "$matchDistance" ]; then
			log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Artist Search :: Deezer :: $type :: $lidarrReleaseTitle :: $lidarrAlbumReleaseTitleClean vs $deezerAlbumTitleClean :: Deezer MATCH Found :: Calculated Difference = $diff"

			# Execute Download
			log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Artist Search :: Deezer  :: $type :: $lidarrReleaseTitle :: Downloading $deezerAlbumTrackCount Tracks :: $deezerAlbumTitle ($downloadedReleaseYear)"
			
			DownloadProcess "$deezerAlbumID" "DEEZER" "$downloadedReleaseYear" "$deezerAlbumTitle" "$deezerAlbumTrackCount"
		else
			log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Artist Search :: Deezer :: $type :: $lidarrReleaseTitle :: $lidarrAlbumReleaseTitleClean vs $deezerAlbumTitleClean :: Deezer  Match Not Found :: Calculated Difference ($diff) greater than $matchDistance"
		fi

		# End search if lidarr was successfully notified for import
		if [ "$lidarrDownloadImportNotfication" == "true" ]; then
			break
		fi
	done	
}

FuzzyDeezerSearch () {
	# Required Inputs
	# $1 Process ID
	# $2 Lyric Type (explicit = true, clean = false)

	if [ "$2" == "true" ]; then
		type="Explicit"
	else
		type="Clean"
	fi

	if [ ! -d /config/extended/cache/deezer ]; then
		mkdir -p /config/extended/cache/deezer
	fi

	log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Fuzzy Search :: Deezer :: $type :: $lidarrReleaseTitle :: Searching... (Track Count: $lidarrAlbumReleasesMinTrackCount-$lidarrAlbumReleasesMaxTrackCount)"

	deezerSearch=""
	if [ "$lidarrArtistForeignArtistId" == "89ad4ac3-39f7-470e-963a-56509c546377" ]; then
		# Search without Artist for VA albums
		deezerSearch=$(curl -s "https://api.deezer.com/search?q=album:%22${albumTitleSearch}%22&strict=on&limit=20" | jq -r ".data[]")
	else
		# Search with Artist for non VA albums
		deezerSearch=$(curl -s "https://api.deezer.com/search?q=artist:%22${albumArtistNameSearch}%22%20album:%22${albumTitleSearch}%22&strict=on&limit=20" | jq -r ".data[]")
	fi
	resultsCount=$(echo "$deezerSearch" | jq -r .album.id | sort -u | wc -l)
	log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Fuzzy Search :: Deezer :: $type :: $lidarrReleaseTitle :: $resultsCount search results found"
	if [ ! -z "$deezerSearch" ]; then
		for deezerAlbumID in $(echo "$deezerSearch" | jq -r .album.id | sort -u); do
			deezerAlbumData="$(echo "$deezerSearch" | jq -r ".album | select(.id==$deezerAlbumID)")"
			deezerAlbumTitle="$(echo "$deezerAlbumData" | jq -r ".title")"
			deezerAlbumTitle="$(echo "$deezerAlbumTitle" | head -n1)"
			deezerAlbumTitleClean="$(echo "$deezerAlbumTitle" | sed -e "s%[^[:alpha:][:digit:]]%%g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')"
			deezerAlbumTitleClean="${deezerAlbumTitleClean:0:130}"

			GetDeezerAlbumInfo "${deezerAlbumID}"
			deezerAlbumData="$(cat "/config/extended/cache/deezer/$deezerAlbumID.json")"
			deezerAlbumTrackCount="$(echo "$deezerAlbumData" | jq -r .nb_tracks)"
			deezerAlbumExplicitLyrics="$(echo "$deezerAlbumData" | jq -r .explicit_lyrics)"								
			downloadedReleaseDate="$(echo "$deezerAlbumData" | jq -r .release_date)"
			downloadedReleaseYear="${downloadedReleaseDate:0:4}"

			if [ "$deezerAlbumExplicitLyrics" != "$2" ]; then
				continue
			fi

			# Reject release if greater than the max track count
			if [ "$deezerAlbumTrackCount" -gt "$lidarrAlbumReleasesMaxTrackCount" ]; then
				continue
			fi

			# Reject release if less than the min track count
			if [ "$deezerAlbumTrackCount" -lt "$lidarrAlbumReleasesMinTrackCount" ]; then
				continue
			fi

			log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Fuzzy Search :: Deezer :: $type :: $lidarrReleaseTitle :: $lidarrAlbumReleaseTitleClean vs $deezerAlbumTitleClean :: Checking for Match..."
			log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Fuzzy Search :: Deezer :: $type :: $lidarrReleaseTitle :: $lidarrAlbumReleaseTitleClean vs $deezerAlbumTitleClean :: Calculating Damerau-Levenshtein distance..."
			diff=$(python -c "from pyxdameraulevenshtein import damerau_levenshtein_distance; print(damerau_levenshtein_distance(\"${lidarrAlbumReleaseTitleClean,,}\", \"${deezerAlbumTitleClean,,}\"))" 2>/dev/null)
			if [ "$diff" -le "$matchDistance" ]; then
				log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Fuzzy Search :: Deezer :: $type :: $lidarrReleaseTitle :: $lidarrAlbumReleaseTitleClean vs $deezerAlbumTitleClean :: Deezer MATCH Found :: Calculated Difference = $diff"
				log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Fuzzy Search :: Deezer :: $type :: $lidarrReleaseTitle :: Downloading $deezerAlbumTrackCount Tracks :: $deezerAlbumTitle ($downloadedReleaseYear)"
				
				DownloadProcess "$deezerAlbumID" "DEEZER" "$downloadedReleaseYear" "$deezerAlbumTitle" "$deezerAlbumTrackCount"
			else
				log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Fuzzy Search :: Deezer :: $type :: $lidarrReleaseTitle :: $lidarrAlbumReleaseTitleClean vs $deezerAlbumTitleClean :: Deezer  Match Not Found :: Calculated Difference ($diff) greater than $matchDistance"
			fi
			# End search if lidarr was successfully notified for import
			if [ "$lidarrDownloadImportNotfication" == "true" ]; then
				break
			fi
		done
		log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Fuzzy Search :: Deezer :: $type :: $lidarrReleaseTitle :: ERROR :: Results found, but none matching search criteria..."
	else
		log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Fuzzy Search :: Deezer :: $type :: $lidarrReleaseTitle :: ERROR :: No results found via Fuzzy Search..."
	fi
	
}

ArtistTidalSearch () {
	# Required Inputs
	# $1 Process ID
	# $2 Tidal Artist ID
	# $3 Lyric Type (true or false) - false = Clean, true = Explicit

	# Get tidal artist album list
	if [ ! -f /config/extended/cache/tidal/$2-albums.json ]; then
		curl -s "https://api.tidal.com/v1/artists/$2/albums?limit=10000&countryCode=$tidalCountryCode&filter=ALL" -H 'x-tidal-token: CzET4vdadNUFQ5JU' > /config/extended/cache/tidal/$2-albums.json
		sleep $sleepTimer
	fi

	if [ ! -f "/config/extended/cache/tidal/$2-albums.json" ]; then
		return
	fi

	if [ "$3" == "true" ]; then
		type="Explicit"
	else
		type="Clean"
	fi


	log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Artist Search :: Tidal :: $type :: $lidarrReleaseTitle :: Searching $2... (Track Count: $lidarrAlbumReleasesMinTrackCount-$lidarrAlbumReleasesMaxTrackCount)..."
	tidalArtistAlbumsData=$(cat "/config/extended/cache/tidal/$2-albums.json" | jq -r ".items | sort_by(.numberOfTracks) | sort_by(.explicit) | reverse |.[] | select((.numberOfTracks <= $lidarrAlbumReleasesMaxTrackCount) and .numberOfTracks >= $lidarrAlbumReleasesMinTrackCount)")

	log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Artist Search :: Tidal :: $type :: $lidarrReleaseTitle :: Filtering results by lyric type, track count"
	tidalArtistAlbumsIds=$(echo "${tidalArtistAlbumsData}" | jq -r "select(.explicit=="$3") | .id")

	if [ -z "$tidalArtistAlbumsIds" ]; then
		log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Artist Search :: Tidal :: $type :: $lidarrReleaseTitle :: ERROR :: No search results found..."
		return
	fi

	searchResultCount=$(echo "$tidalArtistAlbumsIds" | wc -l)
	log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Artist Search :: Tidal :: $type :: $lidarrReleaseTitle :: $searchResultCount search results found"
	for tidalArtistAlbumId in $(echo $tidalArtistAlbumsIds); do
			
		tidalArtistAlbumData=$(echo "$tidalArtistAlbumsData" | jq -r "select(.id=="$tidalArtistAlbumId")")
		downloadedAlbumTitle="$(echo ${tidalArtistAlbumData} | jq -r .title)"
		tidalAlbumTitleClean=$(echo ${downloadedAlbumTitle} | sed -e "s%[^[:alpha:][:digit:]]%%g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')
  		tidalAlbumTitleClean="${tidalAlbumTitleClean:0:130}"
		downloadedReleaseDate="$(echo ${tidalArtistAlbumData} | jq -r .releaseDate)"
		if [ "$downloadedReleaseDate" == "null" ]; then
			downloadedReleaseDate=$(echo $tidalArtistAlbumData | jq -r '.streamStartDate')
		fi
		downloadedReleaseYear="${downloadedReleaseDate:0:4}"
		downloadedTrackCount=$(echo "$tidalArtistAlbumData"| jq -r .numberOfTracks)

		log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Artist Search :: Tidal :: $type :: $lidarrReleaseTitle :: $lidarrAlbumReleaseTitleClean vs $tidalAlbumTitleClean :: Checking for Match..."
		log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Artist Search :: Tidal :: $type :: $lidarrReleaseTitle :: $lidarrAlbumReleaseTitleClean vs $tidalAlbumTitleClean :: Calculating Damerau-Levenshtein distance..."
		diff=$(python -c "from pyxdameraulevenshtein import damerau_levenshtein_distance; print(damerau_levenshtein_distance(\"${lidarrAlbumReleaseTitleClean,,}\", \"${tidalAlbumTitleClean,,}\"))" 2>/dev/null)
		if [ "$diff" -le "$matchDistance" ]; then
			log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Artist Search :: Tidal :: $type :: $lidarrReleaseTitle :: $lidarrAlbumReleaseTitleClean vs $tidalAlbumTitleClean :: Tidal MATCH Found :: Calculated Difference = $diff"

			# Execute Download
			log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Artist Search :: Tidal :: $type :: $lidarrReleaseTitle :: Downloading $downloadedTrackCount Tracks :: $downloadedAlbumTitle ($downloadedReleaseYear)"
			
			DownloadProcess "$tidalArtistAlbumId" "TIDAL" "$downloadedReleaseYear" "$downloadedAlbumTitle" "$downloadedTrackCount"
			# End search if lidarr was successfully notified for import
			if [ "$lidarrDownloadImportNotfication" == "true" ]; then
				break
			fi
		else
			log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Artist Search :: Tidal :: $type :: $lidarrReleaseTitle :: $lidarrAlbumReleaseTitleClean vs $tidalAlbumTitleClean :: Tidal Match Not Found :: Calculated Difference ($diff) greater than $matchDistance"
		fi
	done
	
}

FuzzyTidalSearch () {
	# Required Inputs
	# $1 Process ID
	# $2 Lyric Type (explicit = true, clean = false)

	if [ "$2" == "true" ]; then
		type="Explicit"
	else
		type="Clean"
	fi

	log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Fuzzy Search :: Tidal :: $type :: $lidarrReleaseTitle :: Searching... (Track Count: $lidarrAlbumReleasesMinTrackCount-$lidarrAlbumReleasesMaxTrackCount)..."
	
	if [ "$lidarrArtistForeignArtistId" == "89ad4ac3-39f7-470e-963a-56509c546377" ]; then
		# Search without Artist for VA albums
		tidalSearch=$(curl -s "https://api.tidal.com/v1/search/albums?query=${albumTitleSearch}&countryCode=${tidalCountryCode}&limit=20" -H 'x-tidal-token: CzET4vdadNUFQ5JU' | jq -r ".items | sort_by(.numberOfTracks) | sort_by(.explicit) | reverse |.[] | select(.explicit=="$2") | select((.numberOfTracks <= $lidarrAlbumReleasesMaxTrackCount) and .numberOfTracks >= $lidarrAlbumReleasesMinTrackCount)")
	else
		# Search with Artist for non VA albums
		tidalSearch=$(curl -s "https://api.tidal.com/v1/search/albums?query=${albumArtistNameSearch}%20${albumTitleSearch}&countryCode=${tidalCountryCode}&limit=20" -H 'x-tidal-token: CzET4vdadNUFQ5JU' | jq -r ".items | sort_by(.numberOfTracks) | sort_by(.explicit) | reverse |.[]| select(.explicit=="$2") | select((.numberOfTracks <= $lidarrAlbumReleasesMaxTrackCount) and .numberOfTracks >= $lidarrAlbumReleasesMinTrackCount)")
	fi
	sleep $sleepTimer
	tidalSearch=$(echo "$tidalSearch" | jq -r )
	searchResultCount=$(echo "$tidalSearch" | jq -r ".id" | sort -u | wc -l)
	log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Fuzzy Search :: Tidal :: $type :: $lidarrReleaseTitle :: $searchResultCount search results found"
	if [ ! -z "$tidalSearch" ]; then
		for tidalAlbumID in $(echo "$tidalSearch" | jq -r .id | sort -u); do
			tidalAlbumData="$(echo "$tidalSearch" | jq -r "select(.id==$tidalAlbumID)")"
			tidalAlbumTitle=$(echo "$tidalAlbumData"| jq -r .title)
			tidalAlbumTitleClean=$(echo ${tidalAlbumTitle} | sed -e "s%[^[:alpha:][:digit:]]%%g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')
   			tidalAlbumTitleClean="${tidalAlbumTitleClean:0:130}"
			downloadedReleaseDate="$(echo ${tidalAlbumData} | jq -r .releaseDate)"
			if [ "$downloadedReleaseDate" == "null" ]; then
				downloadedReleaseDate=$(echo $tidalAlbumData | jq -r '.streamStartDate')
			fi
			downloadedReleaseYear="${downloadedReleaseDate:0:4}"
			downloadedTrackCount=$(echo "$tidalAlbumData"| jq -r .numberOfTracks)

			log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Fuzzy Search :: Tidal :: $type :: $lidarrReleaseTitle :: $lidarrAlbumReleaseTitleClean vs $tidalAlbumTitleClean :: Checking for Match..."
			log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Fuzzy Search :: Tidal :: $type :: $lidarrReleaseTitle :: $lidarrAlbumReleaseTitleClean vs $tidalAlbumTitleClean :: Calculating Damerau-Levenshtein distance..."
			diff=$(python -c "from pyxdameraulevenshtein import damerau_levenshtein_distance; print(damerau_levenshtein_distance(\"${lidarrAlbumReleaseTitleClean,,}\", \"${tidalAlbumTitleClean,,}\"))" 2>/dev/null)
			if [ "$diff" -le "$matchDistance" ]; then
				log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Fuzzy Search :: Tidal :: $type :: $lidarrReleaseTitle :: $lidarrAlbumReleaseTitleClean vs $tidalAlbumTitleClean :: Tidal MATCH Found :: Calculated Difference = $diff"
				log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Fuzzy Search :: Tidal :: $type :: $lidarrReleaseTitle :: Downloading $downloadedTrackCount Tracks :: $tidalAlbumTitle ($downloadedReleaseYear)"
				
				DownloadProcess "$tidalAlbumID" "TIDAL" "$downloadedReleaseYear" "$tidalAlbumTitle" "$downloadedTrackCount"

			else
				log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Fuzzy Search :: Tidal :: $type :: $lidarrReleaseTitle :: $lidarrAlbumReleaseTitleClean vs $tidalAlbumTitleClean :: Tidal Match Not Found :: Calculated Difference ($diff) greater than $matchDistance"
			fi
			# End search if lidarr was successfully notified for import
			if [ "$lidarrDownloadImportNotfication" == "true" ]; then
				break
			fi
		done
		log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Fuzzy Search :: Tidal :: $type :: $lidarrReleaseTitle :: ERROR :: Albums found, but none matching search criteria..."
	else
		log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Fuzzy Search :: Tidal :: $type :: $lidarrReleaseTitle :: ERROR :: No results found..."
	fi
}

YoutubeClientSetup () {
	log "YOUTUBE :: Verifying yt-dlp configuration"
	if ! command -v yt-dlp >/dev/null 2>&1; then
		log "YOUTUBE :: ERROR :: yt-dlp not found in container -- youtube client will be skipped this run"
		youtubeClientEnabled="false"
		return
	fi
	youtubeClientEnabled="true"
	log "YOUTUBE :: yt-dlp version: $(yt-dlp --version 2>/dev/null)"

	if [ -f /config/cookies.txt ]; then
		youtubeCookiesFile="/config/cookies.txt"
		log "YOUTUBE :: Cookies file found (/config/cookies.txt)"
	else
		youtubeCookiesFile=""
		log "YOUTUBE :: No cookies file. YouTube blocks datacenter/VPN IPs with a bot check -- downloads will fail without authenticated cookies at /config/cookies.txt"
	fi

	if [ -n "$youtubeYtdlpArgs" ]; then
		log "YOUTUBE :: Extra yt-dlp args: $youtubeYtdlpArgs"
	fi

	if [ -n "$youtubeVpnProxy" ]; then
		log "YOUTUBE :: Proxy: $youtubeVpnProxy"
	else
		log "YOUTUBE :: Proxy: disabled (set youtubeVpnProxy in extended.conf to tunnel yt-dlp through a VPN)"
	fi

	mkdir -p /config/extended/cache/youtube
	chmod 777 /config/extended/cache/youtube
	log "YOUTUBE :: Purging per-track search cache..."
	rm -f /config/extended/cache/youtube/*.json /config/extended/cache/youtube/*.tracks &>/dev/null

	# Write the per-track candidate scorer used by YoutubeSearch (title
	# Damerau-Levenshtein distance + duration delta, prefers artist/"- Topic"
	# uploads). stdin = a yt-dlp -J search result; prints "id<TAB>dur<TAB>title"
	# for the best candidate iff its score is within threshold.
	cat > /config/extended/cache/youtube/_scorer.py <<'PYEOF'
import sys, json, re

want_title = sys.argv[1]
want_dur   = float(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2] not in ("", "0", "null") else 0.0
artist     = sys.argv[3] if len(sys.argv) > 3 else ""
threshold  = float(sys.argv[4]) if len(sys.argv) > 4 else 0.30
dur_tol    = float(sys.argv[5]) if len(sys.argv) > 5 else 15.0

try:
    from pyxdameraulevenshtein import normalized_damerau_levenshtein_distance as ndist
except Exception:
    def ndist(a, b):
        if a == b:
            return 0.0
        la, lb = len(a), len(b)
        prev = list(range(lb + 1))
        for i in range(1, la + 1):
            cur = [i] + [0] * lb
            for j in range(1, lb + 1):
                cost = 0 if a[i - 1] == b[j - 1] else 1
                cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
            prev = cur
        return prev[lb] / max(la, lb, 1)

JUNK = re.compile(
    r'[\(\[][^\)\]]*[\)\]]'                       # (parentheticals) / [brackets]
    r'|\bfeat(uring)?\b.*$'                        # "feat. X" and everything after
    r'|\b(official|officiel|video|videoclip|audio|lyrics?|lyric video|visuali[sz]er|'
    r'hd|hq|4k|8k|mv|remaster(ed)?|explicit|clean|full album|topic|from|the album)\b',
    re.I)

def norm(s):
    s = JUNK.sub(' ', s or '')
    return re.sub(r'[^a-z0-9]+', ' ', s.lower()).strip()

def toks(s):
    return set(t for t in s.split() if t)

def cover_dist(a, b):
    # fraction of the SHORTER token set that is missing from the longer one.
    # 0.0 == every word of the shorter title appears in the other.
    sa, sb = toks(a), toks(b)
    if not sa or not sb:
        return 1.0
    short = sa if len(sa) <= len(sb) else sb
    other = sb if short is sa else sa
    return len(short - other) / len(short)

wt = norm(want_title)
ar = norm(artist)

best = None
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for e in (data.get('entries') or []):
    if not e:
        continue
    vid = e.get('id')
    if not vid:
        continue
    ct = e.get('title') or ''
    cd = e.get('duration') or 0
    ch = norm(e.get('channel') or e.get('uploader') or '')
    cn = norm(ct)
    cn2 = re.sub(r'^' + re.escape(ar) + r'\s+', '', cn) if ar else cn
    # title score: best of full edit distance and token coverage. Coverage gets
    # a 0.15 floor so a shorter YouTube title that merely contains all the
    # Lidarr words can't win outright -- the duration term decides between them.
    tscore = min(ndist(wt, cn), ndist(wt, cn2),
                 0.15 + cover_dist(wt, cn), 0.15 + cover_dist(wt, cn2))
    score = tscore
    if want_dur and cd:
        dd = abs(cd - want_dur)
        score += 10.0 if dd > dur_tol else dd / (dur_tol * 4.0)
    elif want_dur and not cd:
        score += 0.30
    if ar and ar in ch:
        score -= 0.15
    if best is None or score < best[0]:
        best = (score, vid, ct, int(cd or 0))

if best and best[0] <= threshold:
    sys.stdout.write("%s\t%d\t%s\n" % (best[1], best[3], best[2]))
PYEOF
	chmod 777 /config/extended/cache/youtube/_scorer.py

	if [ ! -d "$audioPath/incomplete" ]; then
		mkdir -p "$audioPath"/incomplete
		chmod 777 "$audioPath"/incomplete
	fi
}

YoutubeSearch () {
	# $1 Process ID prefix
	# Matches the current album's Lidarr track list song-by-song on YouTube
	# Music (falling back to plain YouTube), scoring candidates by title
	# distance + duration. Only if EVERY track gets a match does it hand the
	# assembled list to DownloadProcess. One pass, no lyric filter.

	if [ "$youtubeClientEnabled" != "true" ]; then
		return
	fi

	local proc="$1"

	# YouTube audio is always lossy -- a lossless/master requirement rejects
	# every result, so skip before wasting searches + downloads.
	if [ "$requireQuality" == "true" ] && [ "$audioFormat" == "native" ] && { [ "$audioBitrate" == "master" ] || [ "$audioBitrate" == "lossless" ]; }; then
		log "$proc :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: YouTube :: WARNING :: requireQuality + audioBitrate=$audioBitrate rejects all lossy YouTube audio -- skipping YouTube for this album"
		return
	fi

	mkdir -p /config/extended/cache/youtube 2>/dev/null
	local scorer="/config/extended/cache/youtube/_scorer.py"
	if [ ! -f "$scorer" ]; then
		log "$proc :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: YouTube :: ERROR :: scorer missing (run YoutubeClientSetup)"
		return
	fi

	ytdlpProxyArgs=()
	[ -n "$youtubeVpnProxy" ] && ytdlpProxyArgs=(--proxy "$youtubeVpnProxy")
	ytdlpCookieArgs=()
	[ -n "$youtubeCookiesFile" ] && ytdlpCookieArgs=(--cookies "$youtubeCookiesFile")
	ytdlpExtraArgs=()
	[ -n "$youtubeYtdlpArgs" ] && read -ra ytdlpExtraArgs <<< "$youtubeYtdlpArgs"

	# Pull the album's track list (title + duration + numbers) from Lidarr
	local tracksJson
	tracksJson="$(curl -s "$arrUrl/api/v1/track?albumId=$wantedAlbumId&apikey=${arrApiKey}")"
	if ! jq -e 'type=="array"' >/dev/null 2>&1 <<<"$tracksJson"; then
		log "$proc :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: YouTube :: ERROR :: could not read track list from Lidarr"
		return
	fi
	local nTracks
	nTracks="$(jq -r 'length' <<<"$tracksJson")"
	if [ -z "$nTracks" ] || [ "$nTracks" -lt 1 ]; then
		log "$proc :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: YouTube :: ERROR :: Lidarr returned 0 tracks"
		return
	fi

	local artistQuery="$lidarrArtistNameSearchSanitized"
	if [ "$lidarrArtistForeignArtistId" == "89ad4ac3-39f7-470e-963a-56509c546377" ]; then
		artistQuery=""
	fi

	local matchFile="/config/extended/cache/youtube/${lidarrAlbumForeignAlbumId}.tracks"
	: > "$matchFile"

	log "$proc :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: YouTube :: Matching $nTracks tracks song-by-song (title threshold $youtubeMatchThreshold, duration +-${youtubeDurationTolerance}s)..."

	local matched=0 i=0 tLine tTitle tDurMs tDurS tNum tMed tClean searchFile best bId bDur bTitle outBase
	while IFS= read -r tLine; do
		i=$(( i + 1 ))
		tTitle="$(jq -r '.title // ""' <<<"$tLine")"
		tDurMs="$(jq -r '.duration // 0' <<<"$tLine")"
		tNum="$(jq -r '(.trackNumber // .absoluteTrackNumber // 0) | tostring' <<<"$tLine" | sed 's/[^0-9]//g')"
		tMed="$(jq -r '.mediumNumber // 1' <<<"$tLine")"
		[ -z "$tNum" ] && tNum="$i"
		[ -z "$tMed" ] && tMed=1
		tDurS=$(( tDurMs / 1000 ))

		if [ -z "$tTitle" ]; then
			log "$proc :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: YouTube :: track $i/$nTracks :: ERROR :: no title from Lidarr"
			continue
		fi

		tClean="$(echo "$tTitle" | sed -e "s%[^[:alpha:][:digit:]]% %g" -e "s/  */ /g" | sed 's/^ *//g' | sed 's/ *$//g')"
		searchFile="/config/extended/cache/youtube/${lidarrAlbumForeignAlbumId}-d${tMed}t${tNum}.json"

		# Plain YouTube search -- flat results carry duration + channel, which the
		# YT Music search tab does not. Try "<artist> <title>", then "<title>".
		if [ ! -f "$searchFile" ] || ! jq -e '((.entries // []) | length) > 0' >/dev/null 2>&1 < "$searchFile"; then
			timeout "$downloadClientTimeOut" yt-dlp -J --flat-playlist --no-warnings --geo-bypass \
				"${ytdlpProxyArgs[@]}" "${ytdlpCookieArgs[@]}" "${ytdlpExtraArgs[@]}" \
				"ytsearch${youtubeSearchResults}:${artistQuery} ${tClean}" \
				> "$searchFile" 2>>"/config/logs/$logFileName" < /dev/null
			sleep $sleepTimer
			if [ -n "$artistQuery" ] && ! jq -e '((.entries // []) | length) > 0' >/dev/null 2>&1 < "$searchFile"; then
				timeout "$downloadClientTimeOut" yt-dlp -J --flat-playlist --no-warnings --geo-bypass \
					"${ytdlpProxyArgs[@]}" "${ytdlpCookieArgs[@]}" "${ytdlpExtraArgs[@]}" \
					"ytsearch${youtubeSearchResults}:${tClean}" \
					> "$searchFile" 2>>"/config/logs/$logFileName" < /dev/null
				sleep $sleepTimer
			fi
		fi
		if ! jq -e . >/dev/null 2>&1 < "$searchFile"; then
			log "$proc :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: YouTube :: track $i/$nTracks :: '$tTitle' :: no search results -- skipping YouTube for this album"
			rm -f "$searchFile"
			break
		fi

		# pass the RAW Lidarr title so the scorer can strip "(...)" / "feat." itself
		best="$(python "$scorer" "$tTitle" "$tDurS" "$lidarrArtistNameSearchSanitized" "$youtubeMatchThreshold" "$youtubeDurationTolerance" < "$searchFile" 2>>"/config/logs/$logFileName")"
		if [ -z "$best" ]; then
			log "$proc :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: YouTube :: track $i/$nTracks :: '$tTitle' (${tDurS}s) :: NO acceptable match -- skipping YouTube for this album"
			break
		fi
		bId="$(cut -f1 <<<"$best")"
		bDur="$(cut -f2 <<<"$best")"
		bTitle="$(cut -f3- <<<"$best")"

		if [ "$tMed" -gt 1 ] 2>/dev/null; then
			outBase="$(printf '%d-%02d - %s' "$tMed" "$tNum" "$tClean")"
		else
			outBase="$(printf '%02d - %s' "$tNum" "$tClean")"
		fi
		outBase="$(echo "$outBase" | sed 's#[/\\]# #g')"
		printf '%s\t%s\n' "$bId" "$outBase" >> "$matchFile"
		matched=$(( matched + 1 ))
		log "$proc :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: YouTube :: track $i/$nTracks :: '$tTitle' (${tDurS}s) -> yt:$bId (${bDur}s) '$bTitle'"
	done < <(jq -c '.[]' <<<"$tracksJson")

	if [ "$matched" -ne "$nTracks" ]; then
		log "$proc :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: YouTube :: Only $matched/$nTracks tracks matched -- skipping YouTube for this album"
		rm -f "$matchFile"
		return
	fi

	log "$proc :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: YouTube :: All $nTracks tracks matched -- downloading"
	DownloadProcess "yt-${lidarrAlbumForeignAlbumId}" "YOUTUBE" "$lidarrAlbumReleaseYear" "$lidarrAlbumTitle" "$nTracks"
}

LidarrTaskStatusCheck () {
	alerted=no
	until false
	do
		taskCount=$(curl -s "$arrUrl/api/v1/command?apikey=${arrApiKey}" | jq -r '.[] | select(.status=="started") | .name' | wc -l)
		if [ "$taskCount" -ge "1" ]; then
			if [ "$alerted" == "no" ]; then
				alerted=yes
				log "STATUS :: LIDARR BUSY :: Pausing/waiting for all active Lidarr tasks to end..."
			fi
			sleep 2
		else
			break
		fi
	done
}

LidarrMissingAlbumSearch () {

	log "Begin searching for missing artist albums via Lidarr Indexers..."
	lidarrArtistIds=$(echo $lidarrMissingAlbumArtistsData | jq -r .id)
	lidarrArtistIdsCount=$(echo "$lidarrArtistIds" | wc -l)
	processCount=0
	for lidarrArtistId in $(echo $lidarrArtistIds); do
		processCount=$(( $processCount + 1))
		lidarrArtistData=$(echo $lidarrMissingAlbumArtistsData | jq -r "select(.id==$lidarrArtistId)")
		lidarrArtistName=$(echo $lidarrArtistData | jq -r .artistName)
		lidarrArtistMusicbrainzId=$(echo $lidarrArtistData | jq -r .foreignArtistId)
		if [ -d /config/extended/logs/searched/lidarr/artist ]; then
			if [ -f /config/extended/logs/searched/lidarr/artist/$lidarrArtistMusicbrainzId ]; then
				log "$processCount of $lidarrArtistIdsCount :: Previously Notified Lidarr to search for \"$lidarrArtistName\" :: Skipping..."
				continue
			fi
		fi
		log "$processCount of $lidarrArtistIdsCount :: Notified Lidarr to search for \"$lidarrArtistName\""
		startLidarrArtistSearch=$(curl -s "$arrUrl/api/v1/command" -X POST -H "Content-Type: application/json" -H "X-Api-Key: $arrApiKey"  --data-raw "{\"name\":\"ArtistSearch\",\"artistId\":$lidarrArtistId}")
		if [ ! -d /config/extended/logs/searched/lidarr/artist ]; then
			mkdir -p /config/extended/logs/searched/lidarr/artist
			chmod -R 777 /config/extended/logs/searched/lidarr/artist
		fi
		touch /config/extended/logs/searched/lidarr/artist/$lidarrArtistMusicbrainzId
		chmod 777 /config/extended/logs/searched/lidarr/artist/$lidarrArtistMusicbrainzId
	done
}

audioFlacVerification () {
	# Test Flac File for errors
	# $1 File for verification
	verifiedFlacFile=""
	verifiedFlacFile=$(flac --totally-silent -t "$1"; echo $?)
}

NotifyWebhook () {
	if [ "$webHook" ]
	then
		content="$1: $2"
		curl -s -X POST "{$webHook}" -H 'Content-Type: application/json' -d '{"event":"'"$1"'", "message":"'"$2"'", "content":"'"$content"'"}'
	fi
}

AudioProcess () {

  Configuration
  
  # Perform NotFound Folder Cleanup process
  NotFoundFolderCleaner
  
  LidarrRootFolderCheck
  
  DownloadFormat
  
  if clientEnabled deezer; then
  	DeemixClientSetup
  fi

  if clientEnabled tidal; then
  	TidalClientSetup
  fi

  if clientEnabled youtube; then
  	YoutubeClientSetup
  fi

  LidarrTaskStatusCheck

  # Get artist list for LidarrMissingAlbumSearch process, to prevent searching for artists that will not be processed by the script
  lidarrMissingAlbumArtistsData=$(wget --timeout=0 -q -O - "$arrUrl/api/v1/artist?apikey=$arrApiKey" | jq -r .[])

  if [ ${#dlClients[@]} -ge 1 ]; then
  	GetMissingCutOffList
  else
  	log "ERROR :: No valid dlClientSource set"
  	log "ERROR :: Expected any of: deezer tidal youtube both (space or comma separated)"
  	log "ERROR :: dlClientSource set as: \"$dlClientSource\""
  fi
  
  if [ "$addDeezerTopArtists" == "true" ] || [ "$addDeezerTopAlbumArtists" == "true" ] || [ "$addDeezerTopTrackArtists" == "true" ] || [ "$addRelatedArtists" == "true" ]; then
  	LidarrTaskStatusCheck
  	LidarrMissingAlbumSearch
  fi
  
  log "Script end..."
}

log "Starting Script...."
for (( ; ; )); do
	let i++
 	logfileSetup
        verifyConfig
	getArrAppInfo
	verifyApiAccess
	AudioProcess
	log "Script sleeping for $audioScriptInterval..."
	sleep $audioScriptInterval
done

exit
