#!/usr/bin/env bats
load test_helpers
SUT_CONTAINER=bats-nginx-proxy-${TEST_FILE}-1


@test "[$TEST_FILE] start a nginx-proxy container" {
	# GIVEN nginx-proxy
	run nginxproxy $SUT_CONTAINER -v /var/run/docker.sock:/tmp/docker.sock:ro
	assert_success
	docker_wait_for_log $SUT_CONTAINER 3 "Watching docker events"
}


@test "[$TEST_FILE] nginx-proxy default to the service running on port 80" {
	# GIVEN a container exposing 2 webservers on ports 80 and 1234
	local -r WEB_CONTAINER=bats-web-${TEST_FILE}-1
	docker_clean $WEB_CONTAINER
	run docker run -d \
		--name $WEB_CONTAINER \
		-e VIRTUAL_HOST=web.bats \
		--expose 80 \
		--expose 90 \
		-w /var/www/ \
		python:3 sh -c "
			(mkdir /var/www/80; cd /var/www/80; echo 'f00' > data; python -m http.server 80 & )
		     mkdir /var/www/90; cd /var/www/90; echo 'bar' > data; python -m http.server 90
	    "
	assert_success

	run retry 5 1s curl --silent --fail http://$(docker_ip $WEB_CONTAINER):80/data
	assert_output f00

	run retry 5 1s curl --silent --fail http://$(docker_ip $WEB_CONTAINER):90/data
	assert_output bar

	# THEN
	run curl_container $SUT_CONTAINER /data --header "Host: web.bats"
	assert_output f00
}


@test "[$TEST_FILE] VIRTUAL_PORT=90 while port 80 is also exposed" {
	# GIVEN a container exposing 2 webservers on ports 80 and 1234
	local -r WEB_CONTAINER=bats-web-${TEST_FILE}-2
	docker_clean $WEB_CONTAINER
	run docker run -d \
		--name $WEB_CONTAINER \
		-e VIRTUAL_HOST=web.bats \
		-e VIRTUAL_PORT=90 \
		--expose 80 \
		--expose 90 \
		-w /var/www/ \
		python:3 sh -c "
			(mkdir /var/www/80; cd /var/www/80; echo 'f00' > data; python -m http.server 80 & )
			 mkdir /var/www/90; cd /var/www/90; echo 'bar' > data; python -m http.server 90
		"
	assert_success

	run retry 5 1s curl --silent --fail http://$(docker_ip $WEB_CONTAINER):80/data
	assert_output f00

	run retry 5 1s curl --silent --fail http://$(docker_ip $WEB_CONTAINER):90/data
	assert_output bar

	# THEN
	run curl_container $SUT_CONTAINER /data --header "Host: web.bats"
	assert_output bar
}


@test "[$TEST_FILE] a single exposed port != 80" {
	# GIVEN a container exposing 1 webserver on ports 1234
	local -r WEB_CONTAINER=bats-web-${TEST_FILE}-3
	docker_clean $WEB_CONTAINER
	run docker run -d \
		--name $WEB_CONTAINER \
		-e VIRTUAL_HOST=web.bats \
		--expose 1234 \
		-w /var/www/ \
		python:3 sh -c "echo f00 > data; python -m http.server 1234"
	assert_success

	run retry 5 1s curl --silent --fail http://$(docker_ip $WEB_CONTAINER):1234/data
	assert_output f00

	# THEN
	run curl_container $SUT_CONTAINER /data --header "Host: web.bats"
	assert_output f00
}

