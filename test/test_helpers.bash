(
	type docker &>/dev/null || ( echo "docker is not available"; exit 1 )
	type curl &>/dev/null || ( echo "curl is not available"; exit 1 )
)>&2

SUT_IMAGE=jwilder/nginx-proxy:bats
TEST_FILE=$(basename $BATS_TEST_FILENAME .bats)

# load the future Bats stdlib
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
export BATS_LIB="${DIR}/lib/bats"
load "${BATS_LIB}/batslib.bash"


load ${DIR}/lib/helpers.bash
load ${DIR}/lib/docker_helpers.bash
load ${DIR}/lib/nginx_helpers.bash

# Send a HTTP request to the SUT container $1 for path $2 and 
# Additional curl options can be passed as $@
#
# $1 container name
# $2 HTTP path to query
# $@ additional options to pass to the curl command
function curl_container {
	local -r container=$1
	local -r path=$2
	shift 2
	curl --silent \
		--connect-timeout 5 \
		--max-time 20 \
		"$@" \
		http://$(docker_ip $container)${path}
}