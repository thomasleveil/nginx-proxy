
# run the SUT docker container 
# and makes sure it remains started
# and displays the nginx-proxy start logs
function nginxproxy {
    clean_nginxproxy_container \
    && docker run -d \
        --name $SUT_CONTAINER \
        -p 80 \
        "$@" \
        $SUT_IMAGE \
    && wait_for_nginxproxy_container_to_start \
    && nginxproxy_logs
}

# display the nginx-proxy logs
function nginxproxy_logs {
    docker logs $SUT_CONTAINER
}

# wait for the nginxproxy log to contain a given text
# $1 timeout in second
# $* text to wait for
function nginxproxy_wait_for_log {
    local -ir timeout_sec=$1
    shift
    docker_wait_for_log $timeout_sec $SUT_CONTAINER "$*"
}

# Send a HTTP request to the SUT container for path $1 and 
# Additional curl options can be passed as $2
function nginxproxy_curl {
	local -r path=$1
	shift
    curl --silent \
        --connect-timeout 5 \
        --max-time 20 \
        "$@" \
        $(get_SUT_url)$path
}

function clean_nginxproxy_container {
    docker_clean $SUT_CONTAINER
}

function wait_for_nginxproxy_container_to_start {
    sleep .5s  # give time to eventually fail to initialize

    function is_running {
        run docker_running_state $SUT_CONTAINER
        assert_output "true"
    }
    retry 3 1 is_running
}