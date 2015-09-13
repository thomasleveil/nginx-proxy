#!/usr/bin/env bats
load test_helpers


function setup {
	start_web_container 1 >&2
	start_web_container 2 >&2
}

function teardown {
	docker ps -aq | xargs -r docker rm -f >&2
}


@test "[$TEST_FILE] -v /var/run/docker.sock:/tmp/docker.sock:ro" {
	# GIVEN nginx-proxy running on our docker host using the default unix socket 
	run nginxproxy -v /var/run/docker.sock:/tmp/docker.sock:ro
	assert_success
	nginxproxy_wait_for_log 3 "Watching docker events"

	# THEN querying the proxy without Host header → 503
	run nginxproxy_curl / --head
	assert_output -l 0 $'HTTP/1.1 503 Service Temporarily Unavailable\r'

	# THEN querying the proxy with Host header → 200
	assert_web_through_nginxproxy 1
	assert_web_through_nginxproxy 2
}


@test "[$TEST_FILE] -v /var/run/docker.sock:/f00.sock:ro -e DOCKER_HOST=unix:///f00.sock" {
	# GIVEN nginx-proxy running on our docker host using a custom unix socket 
	run nginxproxy -v /var/run/docker.sock:/f00.sock:ro -e DOCKER_HOST=unix:///f00.sock
	assert_success
	nginxproxy_wait_for_log 3 "Watching docker events"

	# THEN querying the proxy without Host header → 503
	run nginxproxy_curl / --head
	assert_output -l 0 $'HTTP/1.1 503 Service Temporarily Unavailable\r'

	# THEN querying the proxy with Host header → 200
	assert_web_through_nginxproxy 1
	assert_web_through_nginxproxy 2
}


@test "[$TEST_FILE] -e DOCKER_HOST=tcp://..." {
	# GIVEN a container exposing our docker host over TCP
	run docker_tcp bats-docker-tcp
	assert_success

	# GIVEN nginx-proxy running on our docker host using tcp to connect to our docker host
	run nginxproxy -e DOCKER_HOST="tcp://bats-docker-tcp:2375" --link bats-docker-tcp:bats-docker-tcp
	assert_success
	nginxproxy_wait_for_log 3 "Watching docker events"

	# THEN querying the proxy without Host header → 503
	run nginxproxy_curl / --head
	assert_output -l 0 $'HTTP/1.1 503 Service Temporarily Unavailable\r'

	# THEN querying the proxy with Host header → 200
	assert_web_through_nginxproxy 1
	assert_web_through_nginxproxy 2
}


@test "[$TEST_FILE] separated containers (nginx + docker-gen + nginx.tmpl)" {
	# GIVEN a simple nginx container
	docker_clean bats-nginx
	run docker run -d \
		--name bats-nginx \
		-v /etc/nginx/conf.d/ \
		-v /etc/nginx/certs/ \
		-p 80 \
		nginx:latest
	assert_success

	# GIVEN docker-gen running on our docker host
	docker_clean bats-docker-gen
	run docker run -d \
		--name bats-docker-gen \
	    -v /var/run/docker.sock:/tmp/docker.sock:ro \
	    -v $BATS_TEST_DIRNAME/../nginx.tmpl:/etc/docker-gen/templates/nginx.tmpl:ro \
		--volumes-from bats-nginx \
	    jwilder/docker-gen:latest \
	    	-notify-sighup bats-nginx \
	    	-watch \
	    	-only-exposed \
	    	/etc/docker-gen/templates/nginx.tmpl \
	    	/etc/nginx/conf.d/default.conf
	assert_success
	run docker_wait_for_log 6 bats-docker-gen "Watching docker events"
	assert_success

	# THEN querying nginx without Host header → 503
	run curl --silent --head http://$(docker_host_ip):$(docker_port bats-nginx 80)/
	assert_output -l 0 $'HTTP/1.1 503 Service Temporarily Unavailable\r'

	# THEN querying nginx with Host header → 200
	run curl --silent http://$(docker_host_ip):$(docker_port bats-nginx 80)/data --header "Host: web1.bats"
	assert_success
	assert_output web1
	
	run curl --silent http://$(docker_host_ip):$(docker_port bats-nginx 80)/data --header "Host: web2.bats"
	assert_success
	assert_output web2
}

