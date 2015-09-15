#!/usr/bin/env bats
load test_helpers

function setup {
	run nginxproxy -v /var/run/docker.sock:/tmp/docker.sock:ro
	assert_success
	nginxproxy_wait_for_log 3 "Watching docker events"
}

function teardown {
	docker ps -aq | xargs -r docker rm -f >&2
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
	run retry 5 .5s curl --silent --fail \
		--connect-timeout 5 \
		--max-time 20 \
		--head http://$(docker_ip bats-multiple-hosts-1):80/
	assert_output -l 0 $'HTTP/1.0 200 OK\r'

	# THEN
	run nginxproxy_curl / --head --header "Host: multiple-hosts-1-A.bats"
	assert_output -l 0 $'HTTP/1.1 200 OK\r' || (echo $output; false)

	# THEN
	run nginxproxy_curl / --head --header "Host: multiple-hosts-1-B.bats"
	assert_output -l 0 $'HTTP/1.1 200 OK\r'
}
