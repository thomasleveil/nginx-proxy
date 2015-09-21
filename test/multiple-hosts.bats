#!/usr/bin/env bats
load test_helpers
SUT_CONTAINER=bats-nginx-proxy-${TEST_FILE}-1

@test "[$TEST_FILE] start a nginx-proxy container" {
	run nginxproxy $SUT_CONTAINER -v /var/run/docker.sock:/tmp/docker.sock:ro
	assert_success
	docker_wait_for_log $SUT_CONTAINER 3 "Watching docker events"
}

@test "[$TEST_FILE] nginx-proxy forwards requests for 2 hosts" {
	# GIVEN a container running a web server
	docker_clean bats-multiple-hosts-1
	run docker run -d \
		--name bats-multiple-hosts-1 \
		-e VIRTUAL_HOST=multiple-hosts-1-A.bats,multiple-hosts-1-B.bats \
		--expose 80 \
		-w /data \
		python:3 python -m http.server 80
	assert_success
	run retry 5 1s curl_container bats-multiple-hosts-1 / --head
	assert_output -l 0 $'HTTP/1.0 200 OK\r'

	# THEN
	run curl_container $SUT_CONTAINER / --head --header 'Host: multiple-hosts-1-A.bats'
	assert_output -l 0 $'HTTP/1.1 200 OK\r' || (echo $output; echo $status; false)

	# THEN
	run curl_container $SUT_CONTAINER / --head --header 'Host: multiple-hosts-1-B.bats'
	assert_output -l 0 $'HTTP/1.1 200 OK\r'
}
