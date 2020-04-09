#!/bin/sh

# Example: curl -N "http://172.17.0.2/logs" | /bin/log-shuttle -logs-url=http://webhook.site/a26ae22d-0cf8-491a-8a32-0aa8907c3318
if [ -z "$LOGSPOUT_URL" ]
then
	echo "Please set \$LOGSPOUT_URL"
elif [ -z "$LOGPLEX_INPUT_URL" ]
then
	echo "Please set \$LOGPLEX_INPUT_URL"
else
	curl -sSN ${LOGSPOUT_URL} | /bin/log-shuttle -logs-url=${LOGPLEX_INPUT_URL} -logplex-token={$LOGPLEX_TOKEN}
fi