#!/usr/bin/env bats
load test_helpers


function setup {
	start_web_container 1 >&2
	start_web_container 2 >&2
}

function teardown {
	docker ps -aq | xargs -r docker rm -f >&2
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
	run retry 5 .5s curl --silent --fail --head http://$(docker_ip bats-wildcard-hosts-1):80/
	assert_output -l 0 $'HTTP/1.0 200 OK\r'

	# GIVEN nginx-proxy
	run nginxproxy -v /var/run/docker.sock:/tmp/docker.sock:ro
	assert_success
	nginxproxy_wait_for_log 3 "Watching docker events"

	# THEN querying the proxy without Host header → 503
	run nginxproxy_curl / --head
	assert_output -l 0 $'HTTP/1.1 503 Service Temporarily Unavailable\r'

	# THEN querying the proxy with Host header → 200
	assert_web_through_nginxproxy 1
	assert_web_through_nginxproxy 2

	run nginxproxy_curl / --head --header "Host: f00.wildcard.bats"
	assert_output -l 0 $'HTTP/1.1 200 OK\r'
	run nginxproxy_curl / --head --header "Host: bar.wildcard.bats"
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
	run retry 5 .5s curl --silent --fail --head http://$(docker_ip bats-wildcard-hosts-2):80/
	assert_output -l 0 $'HTTP/1.0 200 OK\r'

	# GIVEN nginx-proxy
	run nginxproxy -v /var/run/docker.sock:/tmp/docker.sock:ro
	assert_success
	nginxproxy_wait_for_log 3 "Watching docker events"

	# THEN querying the proxy without Host header → 503
	run nginxproxy_curl / --head
	assert_output -l 0 $'HTTP/1.1 503 Service Temporarily Unavailable\r'

	# THEN querying the proxy with Host header → 200
	assert_web_through_nginxproxy 1
	assert_web_through_nginxproxy 2

	run nginxproxy_curl / --head --header "Host: wildcard.bats.f00"
	assert_output -l 0 $'HTTP/1.1 200 OK\r'
	run nginxproxy_curl / --head --header "Host: wildcard.bats.bar"
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
	run retry 5 .5s curl --silent --fail --head http://$(docker_ip bats-wildcard-hosts-3):80/
	assert_output -l 0 $'HTTP/1.0 200 OK\r'

	# GIVEN nginx-proxy
	run nginxproxy -v /var/run/docker.sock:/tmp/docker.sock:ro
	assert_success
	nginxproxy_wait_for_log 3 "Watching docker events"

	# THEN querying the proxy without Host header → 503
	run nginxproxy_curl / --head
	assert_output -l 0 $'HTTP/1.1 503 Service Temporarily Unavailable\r'

	# THEN querying the proxy with Host header → 200
	assert_web_through_nginxproxy 1
	assert_web_through_nginxproxy 2

	run nginxproxy_curl / --head --header "Host: foo.bar.whatever.bats"
	assert_output -l 0 $'HTTP/1.1 200 OK\r'
	run nginxproxy_curl / --head --header "Host: foo.bar.why.not.bats"
	assert_output -l 0 $'HTTP/1.1 200 OK\r'
}