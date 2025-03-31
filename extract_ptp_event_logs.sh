#!/bin/bash

# Settings
NAMESPACE="openshift-ptp"
CONTAINER="cloud-event-proxy"
DAEMONSET="linuxptp-daemon"

# Temp files
TMP_RAW="/tmp/ptp_raw_events.txt"
TMP_JSON="/tmp/ptp_cleaned_events.jsonl"

echo "Extracting logs from $CONTAINER in $NAMESPACE..."
oc logs ds/${DAEMONSET} -n ${NAMESPACE} -c ${CONTAINER} | \
  grep 'event sent' | \
  sed -n 's/.*event sent //p' | \
  sed 's/\\n/ /g' | \
  sed 's/\\"/"/g' | \
  sed 's/"$//' > "$TMP_RAW"

echo "Filtering only valid JSON objects..."
jq -R 'fromjson? | select(type == "object")' "$TMP_RAW" > "$TMP_JSON"

echo
echo "Processing latest events per source..."
echo

# Print header
printf "%-30s %-40s %-35s %-65s %-10s\n" "TIME" "SOURCE" "TYPE" "RESOURCE" "VALUE"
printf "%-30s %-40s %-35s %-65s %-10s\n" "------------------------------" "----------------------------------------" "-----------------------------------" "-----------------------------------------------------------------" "----------"

# Extract & loop line by line
jq -s '
  map(select(
    .source and .type and .data and (.data.values | type == "array")
  )) 
  | group_by(.source)
  | map(max_by(.time))
  | .[]
  | . as $e
  | $e.data.values[]
  | {
      time: $e.time,
      source: $e.source,
      type: $e.type,
      resource: .ResourceAddress,
      value: .value
    }
' "$TMP_JSON" | jq -c '.' | while read -r line; do
  time=$(jq -r '.time' <<< "$line")
  source=$(jq -r '.source' <<< "$line")
  type=$(jq -r '.type' <<< "$line")
  resource=$(jq -r '.resource' <<< "$line")
  value=$(jq -r '.value' <<< "$line")
  printf "%-30s %-40s %-35s %-65s %-10s\n" "$time" "$source" "$type" "$resource" "$value"
done

