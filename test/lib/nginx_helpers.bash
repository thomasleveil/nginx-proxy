
# run the SUT docker container 
# and makes sure it remains started
# and displays the nginx-proxy start logs
#
# $1 SUT container name
# $@ other options for the `docker run` command
function nginxproxy {
	local -r SUT_CONTAINER=$1
	shift
	docker_clean $SUT_CONTAINER \
	&& docker run -d \
		--name $SUT_CONTAINER \
		"$@" \
		$SUT_IMAGE \
	&& wait_for_nginxproxy_container_to_start $SUT_CONTAINER \
	&& docker logs $SUT_CONTAINER
}

# $1 SUT container name
function wait_for_nginxproxy_container_to_start {
	local -r SUT_CONTAINER=$1
	sleep .5s  # give time to eventually fail to initialize

	function is_running {
		run docker_running_state $SUT_CONTAINER
		assert_output "true"
	}
	retry 3 1 is_running
}