#!/usr/bin/env bats
load test_helpers
SUT_CONTAINER=bats-nginx-proxy-${TEST_FILE}-1


@test "[$TEST_FILE] start a nginx-proxy container" {
	run nginxproxy $SUT_CONTAINER -v /var/run/docker.sock:/tmp/docker.sock:ro
	assert_success
	docker_wait_for_log $SUT_CONTAINER 3 "Watching docker events"
}


@test "[$TEST_FILE] *.wildcard.bats" {
	# GIVEN a container running a web server
	docker_clean bats-wildcard-hosts-1
	run docker run -d \
		--name bats-wildcard-hosts-1 \
		-e VIRTUAL_HOST=*.wildcard.bats \
		--expose 80 \
		-w /data \
		python:3 python -m http.server 80
	assert_success
	run retry 5 1s curl --silent --fail --head http://$(docker_ip bats-wildcard-hosts-1):80/
	assert_output -l 0 $'HTTP/1.0 200 OK\r'

	# THEN
	run curl_container $SUT_CONTAINER / --head --header "Host: f00.wildcard.bats"
	assert_output -l 0 $'HTTP/1.1 200 OK\r'

	# THEN
	run curl_container $SUT_CONTAINER / --head --header "Host: bar.wildcard.bats"
	assert_output -l 0 $'HTTP/1.1 200 OK\r'
}

@test "[$TEST_FILE] wildcard.bats.*" {
	# GIVEN a container running a web server
	docker_clean bats-wildcard-hosts-2
	run docker run -d \
		--name bats-wildcard-hosts-2 \
		-e VIRTUAL_HOST=wildcard.bats.* \
		--expose 80 \
		-w /data \
		python:3 python -m http.server 80
	assert_success
	run retry 5 1s curl --silent --fail --head http://$(docker_ip bats-wildcard-hosts-2)/
	assert_output -l 0 $'HTTP/1.0 200 OK\r'

	# THEN
	run curl_container $SUT_CONTAINER / --head --header "Host: wildcard.bats.f00"
	assert_output -l 0 $'HTTP/1.1 200 OK\r'

	# THEN
	run curl_container $SUT_CONTAINER / --head --header "Host: wildcard.bats.bar"
	assert_output -l 0 $'HTTP/1.1 200 OK\r'
}

@test "[$TEST_FILE] ~^foo\.bar\..*\.bats" {
	# GIVEN a container running a web server
	docker_clean bats-wildcard-hosts-3
	run docker run -d \
		--name bats-wildcard-hosts-3 \
		-e VIRTUAL_HOST=~^foo\.bar\..*\.bats \
		--expose 80 \
		-w /data \
		python:3 python -m http.server 80
	assert_success
	run retry 5 1s curl --silent --fail --head http://$(docker_ip bats-wildcard-hosts-3)/
	assert_output -l 0 $'HTTP/1.0 200 OK\r'

	# THEN
	run curl_container $SUT_CONTAINER / --head --header "Host: foo.bar.whatever.bats"
	assert_output -l 0 $'HTTP/1.1 200 OK\r'

	# THEN
	run curl_container $SUT_CONTAINER / --head --header "Host: foo.bar.why.not.bats"
	assert_output -l 0 $'HTTP/1.1 200 OK\r'
}