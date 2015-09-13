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


function get_SUT_url {
    echo "http://$(docker_host_ip):$(docker_port $SUT_CONTAINER 80)"
}


function assert_web_through_nginxproxy {
	local -ir web_id=$1
	# WHEN
	run nginxproxy_curl /data --header "Host: web${web_id}.bats"

	# THEN
	assert_success
	assert_output web${web_id}
}

# start a container named 'bats-web$1' running a webserver listening
# on port 8000 and having the environment variable VIRTUAL_HOST set 
# to `web$1.bats`.
# When a HTTP request is made on path /data, it responds with the 
# content of the file in `fixtures/webservers/$1/data`
function start_web_container {
	local -ir ID=$1
	local -r CONTAINER=bats-web${ID}
	local -r HOST=web${ID}.bats

	local SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
	local FIXTURE_DIR=$SCRIPT_DIR/fixtures/webservers/${ID}/
	if ! [ -d "/./$FIXTURE_DIR" ]; then
		echo "ERROR: fixture dir is missing: $FIXTURE_DIR"
		false
		return
	fi

	docker_clean $CONTAINER
	run docker run -d \
		--name $CONTAINER \
		-e VIRTUAL_HOST=$HOST \
		--expose 8000 \
		-v $FIXTURE_DIR/:/var/www/ \
		-w /var/www \
		python:3 \
		python -m http.server
	assert_success
	# Test that the container behaves
	run retry 20 .5s curl --silent --fail http://$(docker_ip $CONTAINER):8000/data
	assert_output web${ID}
}


#function start_web_container_in_dind {
#	local -r dind="$1"
#	local -r id="$2"
#	local -r container_name=bats-web${id}
#	docker exec $dind rm -f $container_name ||:
#	run \
#		docker exec $dind \
#			docker run -d --name $container_name \
#				-e VIRTUAL_HOST=web${id}.bats \
#				--expose 8080 \
#				-p 8080 \
#				adejonge/helloworld
#	assert_success
#
#	web_port_in_dind=$(docker exec $dind docker port $container_name 8080 | cut -d: -f2)
#	run retry 5 .5s docker exec $dind curl --silent --fail http://localhost:${web_port_in_dind}/
#	assert_output "Hello World from Go in minimal Docker container"
#}#