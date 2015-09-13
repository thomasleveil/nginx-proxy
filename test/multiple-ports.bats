#!/usr/bin/env bats
load test_helpers


function setup {
	start_web_container 1 >&2
	start_web_container 2 >&2
}

function teardown {
	docker ps -aq | xargs -r docker rm -f >&2
}


@test "[$TEST_FILE] nginx-proxy default to the service running on port 80" {
	# GIVEN a container exposing 2 webservers on ports 80 and 1234
	docker_clean bats-multiple-ports-1
	run docker run -d \
		--name bats-multiple-ports-1 \
		-e VIRTUAL_HOST=multiple-ports-1.bats \
		--expose 1234 \
		--expose 80 \
		-v $BATS_TEST_DIRNAME/fixtures/multiple-ports/1.txt:/data80/data \
		-v $BATS_TEST_DIRNAME/fixtures/multiple-ports/2.txt/:/data1234/data \
		python:3 \
			sh -c "(cd /data80/; python -m http.server 80 &); cd /data1234/; python -m http.server 1234"
	assert_success
	run retry 5 .5s curl --silent --fail http://$(docker_ip bats-multiple-ports-1):80/data
	assert_output multiple-ports-1
	run retry 5 .5s curl --silent --fail http://$(docker_ip bats-multiple-ports-1):1234/data
	assert_output multiple-ports-2

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

	run nginxproxy_curl /data --header "Host: multiple-ports-1.bats"
	assert_output multiple-ports-1
}


@test "[$TEST_FILE] VIRTUAL_PORT=1234 while port 80 is also exposed" {
	# GIVEN a container exposing 2 webservers on ports 80 and 1234
	docker_clean bats-multiple-ports-2
	run docker run -d \
		--name bats-multiple-ports-2 \
		-e VIRTUAL_HOST=multiple-ports-2.bats \
		-e VIRTUAL_PORT=1234 \
		--expose 1234 \
		--expose 80 \
		-v $BATS_TEST_DIRNAME/fixtures/multiple-ports/1.txt:/data80/data \
		-v $BATS_TEST_DIRNAME/fixtures/multiple-ports/2.txt/:/data1234/data \
		python:3 \
			sh -c "(cd /data80/; python -m http.server 80 &); cd /data1234/; python -m http.server 1234"
	assert_success
	run retry 5 .5s curl --silent --fail http://$(docker_ip bats-multiple-ports-2):80/data
	assert_output multiple-ports-1
	run retry 5 .5s curl --silent --fail http://$(docker_ip bats-multiple-ports-2):1234/data
	assert_output multiple-ports-2

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

	run nginxproxy_curl /data --header "Host: multiple-ports-2.bats"
	assert_output multiple-ports-2
}


@test "[$TEST_FILE] a single exposed port != 80" {
	# GIVEN a container exposing 1 webserver on ports 1234
	docker_clean bats-multiple-ports-3
	run docker run -d \
		--name bats-multiple-ports-3 \
		-e VIRTUAL_HOST=multiple-ports-3.bats \
		--expose 1234 \
		-v $BATS_TEST_DIRNAME/fixtures/multiple-ports/1.txt:/data1234/data \
		-w /data1234/ \
		python:3 python -m http.server 1234
	assert_success
	run retry 5 .5s curl --silent --fail http://$(docker_ip bats-multiple-ports-3):1234/data
	assert_output multiple-ports-1

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

	run nginxproxy_curl /data --header "Host: multiple-ports-3.bats"
	assert_output multiple-ports-1
}

