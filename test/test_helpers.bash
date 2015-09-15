(
    type docker &>/dev/null || ( echo "docker is not available"; exit 1 )
    type curl &>/dev/null || ( echo "curl is not available"; exit 1 )
)>&2

SUT_IMAGE=jwilder/nginx-proxy:bats
SUT_CONTAINER=bats-nginx-proxy-$(basename $BATS_TEST_FILENAME .bats)
TEST_FILE=$(basename $BATS_TEST_FILENAME .bats)

# load the future Bats stdlib
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
export BATS_LIB="${DIR}/lib/bats"
load "${BATS_LIB}/batslib.bash"


load ${DIR}/lib/helpers.bash
load ${DIR}/lib/docker_helpers.bash
load ${DIR}/lib/nginx_helpers.bash
