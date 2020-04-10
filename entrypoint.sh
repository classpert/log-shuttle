#!/bin/sh

# Example: curl -N "http://172.17.0.2/logs" | /bin/log-shuttle -logs-url=http://webhook.site/a26ae22d-0cf8-491a-8a32-0aa8907c3318
if [ -z "$LOGSPOUT_URL" ]
then
	echo -e "Please set \$LOGSPOUT_URL environment variable"
  exit 1
elif [ -z "$LOGPLEX_INPUT_URL" ] || [ -z "$LOGPLEX_URL" ] || [ -z "$LOGPLEX_AUTH_KEY" ]
then
	echo -e "Please set \$LOGPLEX_URL, \$LOGPLEX_INPUT_URL and \$LOGPLEX_AUTH_KEY environment variables"
  exit 1
elif [ -z "$LOGDRAIN_URL" ]
then
  echo -e "Please set \$LOGDRAIN_URL environment variable"
  exit 1
else
  while [[ "$(curl -H "Authorization: Basic ${LOGPLEX_AUTH_KEY}" -s -o /dev/null -w ''%{http_code}'' ${LOGPLEX_URL}/healthcheck)" != "200" ]]; do
    sleep 1;
    echo 'Waiting for Logplex...';
  done

  echo "Creating Logplex channel 'app'"
  # {"channel_id":1,"tokens":{"app":"t.58a10399-c21d-4e1f-9330-366ba99397b0"}}
  curl -H "Authorization: Basic ${LOGPLEX_AUTH_KEY}" -d '{"tokens": ["app"]}' "${LOGPLEX_URL}/channels" | tee /tmp/logplex-channel

  export CHANNEL_ID=$(cat /tmp/logplex-channel | jq '.channel_id')
  export CHANNEL_TOKEN=$(cat /tmp/logplex-channel | jq '.tokens.app')

  rm  /tmp/logplex-channel

  while [[ "$(curl -H "Authorization: Basic ${LOGPLEX_AUTH_KEY}" -s -o /dev/null -w ''%{http_code}'' ${LOGPLEX_URL}/v2/channels/${CHANNEL_ID})" != "200" ]]; do
    sleep 1;
    echo 'Waiting for Logplex Channel...';
  done

  echo "Creating Logplex drain"
  curl -H "Authorization: Basic ${LOGPLEX_AUTH_KEY}" -d "{\"url\": \"${LOGDRAIN_URL}\"}" "${LOGPLEX_URL}/v2/channels/${CHANNEL_ID}/drains"

	curl -sSN ${LOGSPOUT_URL} | /bin/log-shuttle -logs-url=${LOGPLEX_INPUT_URL} -logplex-token={$LOGPLEX_TOKEN}
fi