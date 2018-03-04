#!/bin/bash

# create two sensor picos
eci1=`curl 'http://localhost:8080/sky/event/Xj862NvJj7HPEHYWhbq5Fh/1337/sensor/new_sensor?name=jose' | jq -r '.directives[0].options.pico.eci'`
eci2=`curl 'http://localhost:8080/sky/event/Xj862NvJj7HPEHYWhbq5Fh/1337/sensor/new_sensor?name=josb' | jq -r '.directives[0].options.pico.eci'`

# send heartbeats to both
curl "http://localhost:8080/sky/event/$eci1/1337/wovyn/heartbeat" -d "`cat highTemp.json`" -H "Content-Type: application/json"
echo
curl "http://localhost:8080/sky/event/$eci2/1337/wovyn/heartbeat" -d "`cat highTemp.json`" -H "Content-Type: application/json"
echo

# check profile
curl "http://localhost:8080/sky/cloud/$eci1/sensor_profile/query"
echo

# get all temps
curl 'http://localhost:8080/sky/cloud/Xj862NvJj7HPEHYWhbq5Fh/manage_sensors/temperatures'
echo

# delete one
curl 'http://localhost:8080/sky/event/Xj862NvJj7HPEHYWhbq5Fh/1337/sensor/unneeded_sensor?name=jose'
echo

# get temps again
curl 'http://localhost:8080/sky/cloud/Xj862NvJj7HPEHYWhbq5Fh/manage_sensors/temperatures'
echo

