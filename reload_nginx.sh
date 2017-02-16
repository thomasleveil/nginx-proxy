#!/bin/bash
# reload nginx configuration
if ! nginx -s reload; then
    # in case of error, display useful debug information
    echo -e "\n-------------------------------------------------------------------------------"
    find /etc/nginx/ -type f -name '*.conf'
    echo -e "-------------------------------------------------------------------------------"
    find /etc/nginx/ -type f -name '*.conf' | while read config_file; do
        echo "> $config_file"
        nl -ba "$config_file"
    done
    exit 1
fi