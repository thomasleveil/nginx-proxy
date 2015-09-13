
# Removes container $1
function docker_clean {
    docker kill $1 &>/dev/null ||:
    sleep .5s
    docker rm -f $1 &>/dev/null ||:
    sleep .5s
}

# print the docker host port which is mapped to a container port
# $1 container name
# $2 container port
function docker_port {
	docker port $1 $2 | cut -d: -f2
}

# get the docker host ip
function docker_host_ip {
	local ip
    if [ -z $DOCKER_HOST] || [[ $DOCKER_HOST == unix://* ]]; then
        ip=127.0.0.1
    else
        ip=$(echo $DOCKER_HOST | sed -e 's|tcp://\(.*\):[0-9]*|\1|')
    fi
    echo $ip
}

# get the ip of docker container $1
function docker_ip {
	docker inspect --format '{{ .NetworkSettings.IPAddress }}' $1
}

# get the running state of container $1
# → true/false
# fails if the container does not exist
function docker_running_state {
    docker inspect -f {{.State.Running}} $1
}

# get the docker container $1 PID
function docker_pid {
	docker inspect --format {{.State.Pid}} $1
}

# asserts logs from container $1 contains $2
function docker_assert_log {
    local -r container=$1
    shift
    run docker logs $container
    assert_output -p "$*"
}

# wait for container $2 to contain a given text in its log
# $1 timeout in second
# $2 container
# $* text to wait for
function docker_wait_for_log {
    local -ir timeout_sec=$1
    shift
    local -r container=$1
    shift
    retry $(( $timeout_sec * 2 )) .5s docker_assert_log $container "$*"
}

# Create a docker container named $1 (or bats-docker-tcp) 
# which exposes the docker host unix socket over tcp.
function docker_tcp {
	local container_name="$1"
	[ "$container_name" = "" ] && container_name="bats-docker-tcp"
	docker rm -f bats-docker-tcp ||:
	docker run -d \
		--name $container_name \
		--expose 2375 \
		-p 2375 \
		-v /var/run/docker.sock:/var/run/docker.sock \
		rancher/socat-docker
	docker -H tcp://localhost:$(docker_port $container_name 2375) version
}

# Create a Docker-in-Docker container named $1
# (or bats-dind if no $1 is provided)
function docker_dind {
    local -r DOCKER_VERSION=$(docker --version | sed -r 's/^Docker version ([0-9.]+).*$/\1/')
    local DOCKER_DAEMON_CMD="docker daemon"
    if [[ "$(vercomp $DOCKER_VERSION '1.8.0')" = "2" ]]; then
        DOCKER_DAEMON_CMD="docker -d"
    fi

    local dind_name
    [ "$1" = "" ] && dind_name="bats-dind" || dind_name="$1"

    docker kill $dind_name ||:
    docker rm -f $dind_name ||:

    docker run -d --name $dind_name \
        --privileged \
        --expose 2375 \
        dockerswarm/dind:$DOCKER_VERSION \
        $DOCKER_DAEMON_CMD -H 0.0.0.0:2375 -H unix:///var/run/docker.sock

    retry 3 1 docker exec $dind_name docker version
}

################################################################################

# compare version $1 against $2
# results:
# - 0 : $1 == $2
# - 1 : $1 >  $2
# - 2 : $1 <  $2
# See http://stackoverflow.com/a/4025065/107049
function vercomp {
    if [[ $1 == $2 ]]
    then
        echo 0
        return
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if [[ -z ${ver2[i]} ]]
        then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]}))
        then
            echo 1
            return
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            echo 2
            return
        fi
    done
    echo 0
}