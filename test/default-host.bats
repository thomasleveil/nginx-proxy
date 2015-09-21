#!/usr/bin/env bats
load test_helpers


@test "[$TEST_FILE] DEFAULT_HOST=web1.bats" {
	# GIVEN a webserver
	docker_clean bats-web
	run docker run -d \
		--name bats-web \
		-e VIRTUAL_HOST=web.bats \
		--expose 80 \
		-w /var/www \
		python:3 \
		python -m http.server 80
	assert_success

	# GIVEN nginx-proxy
	run nginxproxy -v /var/run/docker.sock:/tmp/docker.sock:ro -e DEFAULT_HOST=web.bats
	assert_success
	nginxproxy_wait_for_log 3 "Watching docker events"

	# THEN querying the proxy without Host header → 200
	run nginxproxy_curl / --head
	assert_output -l 0 $'HTTP/1.1 200 OK\r'

	# THEN querying the proxy with any other Host header → 200
	run nginxproxy_curl / --head --header "Host: something.I.just.made.up"
	assert_output -l 0 $'HTTP/1.1 200 OK\r'
}
