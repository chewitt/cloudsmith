#!/bin/bash
# Copyright (C) 2023 Tvheadend Project (https://tvheadend.org)
# SPDX-License-Identifier: MIT

set -euo pipefail

if [ -z "${CLOUDSMITH_API_KEY}" ]; then
  echo "CLOUDSMITH_API_KEY not available, aborting!"
  exit 1
fi

if [ -z "${CLOUDSMITH_OWNER}" ]; then
  echo "CLOUDSMITH_OWNER not available, aborting!"
  exit 1
fi

if [ -z "${CLOUDSMITH_REPO}" ]; then
  echo "CLOUDSMITH_REPO not available, aborting!"
  exit 1
fi

# max pagesize
PAGESIZE="500"

# get repo file count
FILES=$(curl -i --silent --url "https://api.cloudsmith.io/v1/packages/$CLOUDSMITH_OWNER/$CLOUDSMITH_REPO/?page=2&page_size=1" \
             --header "X-Api-Key: $CLOUDSMITH_API_KEY" | \
             awk '/x-pagination-count/ {print $2}' | tr -d '\r')

# calculate the max pages needed
(( PAGE = ( FILES / PAGESIZE ) + 1 ))

# results sorted oldest first
for (( i=1; i<PAGE; i++ )); do
  JSON+=$(curl --silent --request GET \
               --url "https://api.cloudsmith.io/v1/packages/$CLOUDSMITH_OWNER/$CLOUDSMITH_REPO/?page=${i}&page_size=${PAGESIZE}&sort=+date" \
               --header "X-Api-Key: ${CLOUDSMITH_API_KEY}" \
               --header 'accept: application/json' | \
               jq -r '.[]')
done

# array of dates converted to epoch
DATES=$(echo "${JSON}" | jq -r '.uploaded_at | split(".")[0] + "Z" | fromdateiso8601')
DATES=($DATES)

# array of filenames
NAMES=$(echo "${JSON}" | jq -r '.filename')
NAMES=($NAMES)

# array of file slugs
SLUGS=$(echo "${JSON}" | jq -r '.slug_perm')
SLUGS=($SLUGS)

# array length
LENGTH=${#DATES[@]}

# calculate the retention epoch (-180d)
DATEX=$(date -d "-180 days" +%s)

for (( i=0; i<LENGTH; i++ )); do
  if (( ${DATES[$i]} < DATEX )); then
    DATE=$(date -d @"${DATES[$i]}" -I)
    curl --request DELETE \
         --url "https://api.cloudsmith.io/v1/packages/$CLOUDSMITH_OWNER/$CLOUDSMITH_REPO/${SLUGS[$i]}/" \
         --header "X-Api-Key: ${CLOUDSMITH_API_KEY}" \
         --header 'accept: application/json'
    echo "removing: ${DATE} - ${SLUGS[$i]} - ${NAMES[$i]}"
  fi
done

exit
