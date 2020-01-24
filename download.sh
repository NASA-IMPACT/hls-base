#!/bin/bash

# Exit on any error
set -o errexit

id=S2B_MSIL1C_20190902T184919_N0208_R113_T11UNQ_20190902T222415
# workingdir is obtained from variable in sentinel.sh
workingdir=/usr/local
granuledir="${workingdir}/${id}"
safedirectory="${granuledir}/${id}.SAFE"

IFS='_'
# Read into an array as tokens separated by IFS
read -ra ADDR <<< "$id"

mkdir -p "$granuledir"

# Format GCS url and download
url=gs://gcp-public-data-sentinel-2/tiles/${ADDR[5]:1:2}/${ADDR[5]:3:1}/${ADDR[5]:4:2}/${id}.SAFE
gsutil -m cp -r "$url" "$granuledir"
