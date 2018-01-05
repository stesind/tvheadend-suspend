#!/bin/bash

# requires some pakages:
# sudo apt install jq net-tools xmlstarlet
#

if [ -z "$(type -t logit)" ] ; then
	logit() {
		echo tvheadend-check-recordings: $* >&2
		return 0
	}
fi


#
# Check credentials and apply default values
#
TVHEADEND_USER=steffen
TVHEADEND_PASSWORD=steffen

if [ -z "$TVHEADEND_USER" ] || [ -z "$TVHEADEND_PASSWORD" ] ; then
	logit "Missing Tvheadend credentials (user and/or password)"
	exit 1
fi
TVHEADEND_IP=$(echo ${TVHEADEND_IP:-$(hostname -I)} | tr -d [:space:])
TVHEADEND_HTTP_PORT=${TVHEADEND_HTTP_PORT:-9981}
TVHEADEND_HTSP_PORT=${TVHEADEND_HTSP_PORT:-9982}
TVHEADEND_ACTIVITIES_PATH=/etc/autosuspend.d/activities

IsTvheadendBusy()
{
	tvheadend_status=$(curl -s --user $TVHEADEND_USER:$TVHEADEND_PASSWORD http://$TVHEADEND_IP:$TVHEADEND_HTTP_PORT/status.xml)

	# Does also work for more than 1 'recording' element
	recording_status=$(echo $tvheadend_status | xmlstarlet sel -t -v "currentload/recordings/recording/status='Recording'")
	if [ "$recording_status" = "true" ] ; then
		logit "Tvheadend is recording, auto suspend terminated"
		return 1
	fi

	subscriptions=$(echo $tvheadend_status | xmlstarlet sel -t -v "currentload/subscriptions")
	if [ "$subscriptions" -gt "0" ] ; then
		logit "Tvheadend has $subscriptions subscriptions, auto suspend not terminated"
		return 0
	fi

	minutes=$(echo $tvheadend_status | xmlstarlet sel -t -v "currentload/recordings/recording/next")
	if [ -n "$minutes" ] && [ "$minutes" -le "${TVHEADEND_IDLE_MINUTES_BEFORE_RECORDING:-15}" ] ; then
		logit "Next Tvheadend recording starts in $minutes minutes, auto suspend terminated"
		return 1
	fi

	TVHEADEND_PORTS="$TVHEADEND_HTTP_PORT $TVHEADEND_HTSP_PORT"
	LANG=C
	active_clients=()
	for port in $TVHEADEND_PORTS; do
		active_clients+=($(netstat -n | grep -oP "$TVHEADEND_IP:$port\s+\K([^\s]+)(?=:\d+\s+ESTABLISHED)"))
	done
	if [ $active_clients ]; then
		logit "Tvheadend has active clients: $active_clients"
		return 1
	fi

	next_activity=$(FindNextActivity)
	if [ -n "$next_activity" ] ; then
		now=$(date +%s)
		let delta=(next_activity - now)/60
		if [ "$delta" -le "${TVHEADEND_IDLE_MINUTES_BEFORE_RECORDING:-15}" ] ; then
			logit "Next activity starts in $delta minutes, auto suspend terminated"
			return 1
		fi
	fi

	return 0
}

FindNextActivity() {
	# syntax for elements in 'activities': '<source>:<timestamp>:<comment>'
	# comment is optional
	# example: '/etc/autosuspend.d/activities/twice-a-week.sh:1451602800:Boot for EPG'
	activities=()

	# collect Tvheadend schedules
	tvheadend_dvr_upcoming=$(curl -s --user "$TVHEADEND_USER:$TVHEADEND_PASSWORD" "http://$TVHEADEND_IP:$TVHEADEND_HTTP_PORT/api/dvr/entry/grid_upcoming?sort=start_real&dir=ASC&limit=1")
	IFS=$'\n' activities+=($(echo $tvheadend_dvr_upcoming | jq -r ".entries[] | \"Tvheadend schedule:\" + (.start_real | tostring) + \":\" + .channelname + \" - \" + .disp_title + if (.disp_subtitle | length > 0) then \" (\" + .disp_subtitle + \")\" else \"\" end"))
	logit "Fetched next ${#activities[@]} upcoming recordings from Tvheadend"

	# return the earliest future timestamp
	if [ "${#activities[@]}" -gt 0 ]; then
		IFS=$'\n' activities=($(sort -t: -k2 <<<"${activities[*]}"))
		now=$(date +%s)
		for timestamp_def in "${activities[@]}"
		do
			IFS=':' read -r source timestamp comment <<< "$timestamp_def"
			message=""
			if [ -n "$comment" ]
			then
				message=": $comment"
			fi
			message="$(date --date @$timestamp)$message from $source"

			if [ "$timestamp" -gt "$now" ]
			then
				logit "Next activity at $message"
				echo "$timestamp"
				return
			else
				logit "Ignoring past activity at $message"
			fi
		done
	fi
}

SetWakeupTime() {
	next=$(FindNextActivity)
	if [ -n "$next" ]; then
		wake_date=$(($next - ${TVHEADEND_BOOT_DELAY_SECONDS:-180}))
		echo 0 > /sys/class/rtc/rtc0/wakealarm
		logit $(/usr/sbin/rtcwake -m no -t $wake_date)
	else
		logit "No wake up time scheduled. Activity scripts may be added to '$TVHEADEND_ACTIVITIES_PATH'"
	fi
}


# Tvheadend (Im originalscript war exit durch return ersetzt - verursacht fehler)
IsTvheadendBusy
if [ "$?" == "1" ]; then exit 1
fi

SetWakeupTime

exit 0
