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

# get plan limit
LIMIT=$(curl --silent --request GET \
             --url "https://api.cloudsmith.io/v1/quota/oss/$CLOUDSMITH_OWNER/" \
             --header "X-Api-Key: ${CLOUDSMITH_API_KEY}" \
             --header 'accept: application/json' | \
             jq -r '.[].raw.storage.plan_limit')

# target is 90% of limit
TARGET=$(( LIMIT * 90/100 ))

# array of filesizes
SIZES=$(echo "${JSON}" | jq -r '.size')
SIZES=($SIZES)

# array of filenames
NAMES=$(echo "${JSON}" | jq -r '.filename')
NAMES=($NAMES)

# array of file slugs
SLUGS=$(echo "${JSON}" | jq -r '.slug_perm')
SLUGS=($SLUGS)

# array length
LENGTH=${#SIZES[@]}

# calculate before size
BEFORE=$(( ${SIZES[@]/%/ +} 0))

# iterate over the array to take action
for (( i=0; i<LENGTH; i++ )); do

  # if reposize over threshold delete file and element
  if [[ $((${SIZES[@]/%/ +} 0)) -gt $TARGET ]]; then
    curl --request DELETE \
         --url "https://api.cloudsmith.io/v1/packages/$CLOUDSMITH_OWNER/$CLOUDSMITH_REPO/${SLUGS[$i]}/" \
         --header "X-Api-Key: ${CLOUDSMITH_API_KEY}" \
         --header 'accept: application/json'
    echo "deleting: ${SLUGS[$i]} - ${SIZES[$i]} - ${NAMES[$i]}"
    unset NAMES[$i]
    unset SIZES[$i]
    unset SLUGS[$i]
  fi
  NAMES=( ${NAMES[@]} )
  SIZES=( ${SIZES[@]} )
  SLUGS=( ${SLUGS[@]} )

done

# calculate after size
AFTER=$(( ${SIZES[@]/%/ +} 0))

# summary
echo "Cloudsmith Quota Summary:"
echo "  limit $LIMIT"
echo " target $TARGET"
if (( BEFORE > AFTER )); then
  echo "current $AFTER"
else
  echo "current $BEFORE"
fi

exit
