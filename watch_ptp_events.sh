#!/bin/bash

# Namespace and container
NAMESPACE="openshift-ptp"
CONTAINER="cloud-event-proxy"
DAEMONSET="linuxptp-daemon"

echo "📡 Watching logs from $CONTAINER in $NAMESPACE... (press Ctrl+C to stop)"

# Print header once
printf "%-30s %-40s %-35s %-65s %-10s\n" "TIME" "SOURCE" "TYPE" "RESOURCE" "VALUE"
printf "%-30s %-40s %-35s %-65s %-10s\n" "------------------------------" "----------------------------------------" "-----------------------------------" "-----------------------------------------------------------------" "----------"

# Start streaming logs and parsing in real-time
oc logs -f ds/${DAEMONSET} -n ${NAMESPACE} -c ${CONTAINER} | \
grep --line-buffered 'event sent' | \
sed -u -n 's/.*event sent //p' | \
sed -u 's/\\n/ /g' | \
sed -u 's/\\"/"/g' | \
sed -u 's/"$//' | \
jq -R --unbuffered 'fromjson? | select(type == "object")' | \
jq -c --unbuffered '
  select(.source and .type and .data and (.data.values | type == "array"))
  | . as $e
  | $e.data.values[]
  | {
      time: $e.time,
      source: $e.source,
      type: $e.type,
      resource: .ResourceAddress,
      value: .value
    }
' | while read -r line; do
  time=$(jq -r '.time' <<< "$line")
  source=$(jq -r '.source' <<< "$line")
  type=$(jq -r '.type' <<< "$line")
  resource=$(jq -r '.resource' <<< "$line")
  value=$(jq -r '.value' <<< "$line")
  printf "%-30s %-40s %-35s %-65s %-10s\n" "$time" "$source" "$type" "$resource" "$value"
done

