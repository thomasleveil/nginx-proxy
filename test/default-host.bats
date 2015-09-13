#!/usr/bin/env bats
load test_helpers


function setup {
	start_web_container 1 >&2
	start_web_container 2 >&2
}

function teardown {
	docker ps -aq | xargs -r docker rm -f >&2
}


@test "[$TEST_FILE] DEFAULT_HOST=web1.bats" {
	# GIVEN nginx-proxy
	run nginxproxy -v /var/run/docker.sock:/tmp/docker.sock:ro -e DEFAULT_HOST=web1.bats
	assert_success
	nginxproxy_wait_for_log 3 "Watching docker events"

	# THEN querying the proxy with Host header → 200
	assert_web_through_nginxproxy 1
	assert_web_through_nginxproxy 2

	# THEN querying the proxy without Host header → 200
	run nginxproxy_curl /data
	assert_output web1

	# THEN querying the proxy with any other Host header → 200
	run nginxproxy_curl /data "Host: something.I.just.made.up"
	assert_output web1
}
