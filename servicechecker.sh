#!/bin/bash

# By Georgiy Sitnikov.
#
# Will do system Services check and report if needed
#
# AS-IS without any warranty

# Should I send E-Mail?
EmailEnabled=true
Recipients="to_you@mail.mail"
From="somebody@mail.mail"
Subject="Some services has troubles"

Logfile=/var/log/servicechecker.log

# Please do not touch under this line

LOCKFILE=/tmp/servicechecker.lock
EMAILFILE=/tmp/servicechecker.email

# Check if lock file of another instance exist
if [ -f "$LOCKFILE" ]; then

	# Remove lock file if script fails last time and did not run longer than 2 days due to lock file.
	find "$LOCKFILE" -mtime +2 -type f -delete

	echo "$(date) - WARNING - Another instance blocked process."

	exit 1

fi

# Check if config exist

if [ ! -f "servicechecker.conf" ]; then

	echo "$(date) - ERROR - Config file servicechecker.conf was not found. Exiting."

	exit 1

else

	if [ ! -r "servicechecker.conf" ]; then

		echo "$(date) - ERROR - Config file could not be read."

		exit 1

	fi

fi

#ServiceStatusInfo () {
#	service $Servicename status | grep Active: | awk '{$1=""; print $0}'
#}

ServiceRestart () {

	echo "$(date) - Trying to restart $Servicename" >> $LOCKFILE

	service $Servicename stop

	sleep 2

	service $Servicename start

	sleep 10 #give service time to start and fail if it is faulty

	echo "$(date) - INFO - After restart $Servicename is:$(service $Servicename status | grep Active: | awk '{$1=""; print $0}')" >> $LOCKFILE

	SendWarningMail=true

}


ServiceFound () {

	if [ "$ServiceStatus" == "+" ]; then

		echo "$(date) - OK - $Servicename is up and running" >> $LOCKFILE

	else

		if [ "$ServiceStatus" == "-" ]; then

			if [ "$(service $Servicename status | grep Active: | awk '{print $2;}')" == "inactive" ]; then

				echo "$(date) - WARNING - $Servicename is incative. Will not restart. Status:$(service $Servicename status | grep Active: | awk '{$1=""; print $0}')" >> $LOCKFILE

			else

				echo "$(date) - WARNING - $Servicename is down. Current status is:$(service $Servicename status | grep Active: | awk '{$1=""; print $0}')" >> $LOCKFILE

				ServiceRestart

			fi

		else

			echo "$(date) - WARNING - $Servicename is unknown. Current status is:$(service $Servicename status | grep Active: | awk '{$1=""; print $0}')" >> $LOCKFILE

			ServiceRestart

		fi

	fi

}

# Collect all services information
service --status-all > $EMAILFILE

while IFS='' read -r Servicename || [[ -n "$Servicename" ]]; do

	ServiceStatus="$(grep $Servicename $EMAILFILE | cut -d " " -f 3)"

	if [ -n "$ServiceStatus" ]; then

		ServiceFound

	else

		#Double check
		ServiceStatus="$(service $Servicename status | grep Active: | awk '{print $2;}')"

		if [ "$ServiceStatus" == "inactive" ]; then

			echo "$(date) - WARNING - $Servicename is incative. Will not restart. Status:$(service $Servicename status | grep Active: | awk '{$1=""; print $0}')" >> $LOCKFILE

		else

			if [ "$ServiceStatus" == "active" ]; then

			else

				if [ -n "$ServiceStatus" ]; then

					ServiceRestart

				else

					echo "$(date) - ERROR - $Servicename was not found" >> $LOCKFILE

				fi

			fi

		fi

	fi

done < "servicechecker.conf"

# put collected data into Logfile
[ -s $LOCKFILE ] && cat $LOCKFILE >> $Logfile

if [ "$SendWarningMail" == "true" ]  && [ "$EmailEnabled" == "true" ]; then

	#Email Header
	echo 'To: '$Recipients'
FROM: '$From'
Subject: '$Subject'
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="-q1w2e3r4t5"

---q1w2e3r4t5
Content-Type: text/html
Content-Disposition: inline

Some of your services has Faulty status. Please check output below<br><br>' > $EMAILFILE
	[ -s "$LOCKFILE" ] && cat $LOCKFILE >> $EMAILFILE

	# send email with password

	cat $EMAILFILE | /usr/sbin/sendmail $Recipients

fi

#remove temporary files
rm $LOCKFILE


rm $EMAILFILE
exit 0