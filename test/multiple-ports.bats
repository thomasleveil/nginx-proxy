#!/usr/bin/env bats
load test_helpers


function setup {
	# GIVEN nginx-proxy
	run nginxproxy -v /var/run/docker.sock:/tmp/docker.sock:ro
	assert_success
	nginxproxy_wait_for_log 3 "Watching docker events"
}

function teardown {
	docker ps -aq | xargs -r docker rm -f >&2
}


@test "[$TEST_FILE] nginx-proxy default to the service running on port 80" {
	# GIVEN a container exposing 2 webservers on ports 80 and 1234
	run docker run -d \
		--name bats-web \
		-e VIRTUAL_HOST=web.bats \
		--expose 80 \
		--expose 90 \
		-w /var/www/ \
		python:3 sh -c "
			(mkdir /var/www/80; cd /var/www/80; echo 'f00' > data; python -m http.server 80 & )
		     mkdir /var/www/90; cd /var/www/90; echo 'bar' > data; python -m http.server 90
	    "
	assert_success

	run retry 5 1s curl --silent --fail http://$(docker_ip bats-web):80/data
	assert_output f00

	run retry 5 1s curl --silent --fail http://$(docker_ip bats-web):90/data
	assert_output bar

	# THEN
	run nginxproxy_curl /data --header "Host: web.bats"
	assert_output f00
}


@test "[$TEST_FILE] VIRTUAL_PORT=90 while port 80 is also exposed" {
	# GIVEN a container exposing 2 webservers on ports 80 and 1234
	run docker run -d \
		--name bats-web \
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

	run retry 5 1s curl --silent --fail http://$(docker_ip bats-web):80/data
	assert_output f00

	run retry 5 1s curl --silent --fail http://$(docker_ip bats-web):90/data
	assert_output bar

	# THEN
	run nginxproxy_curl /data --header "Host: web.bats"
	assert_output bar
}


@test "[$TEST_FILE] a single exposed port != 80" {
	# GIVEN a container exposing 1 webserver on ports 1234
	run docker run -d \
		--name bats-web \
		-e VIRTUAL_HOST=web.bats \
		--expose 1234 \
		-w /var/www/ \
		python:3 sh -c "echo f00 > data; python -m http.server 1234"
	assert_success

	run retry 5 1s curl --silent --fail http://$(docker_ip bats-web):1234/data
	assert_output f00

	# THEN
	run nginxproxy_curl /data --header "Host: web.bats"
	assert_output f00
}

