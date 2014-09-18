#!/bin/bash
set -e

: ${OWNCLOUD_DB_TYPE:=sqlite}
: ${OWNCLOUD_DB_USER:=root}
: ${OWNCLOUD_DB_NAME:=owncloud}

if [ "$OWNCLOUD_DB_TYPE" != 'sqlite' ]; then
	# If database link of type "mysql" is missing, exit. Also catches spelling errors.
	if [ -z "$MYSQL_PORT_3306_TCP" -a "$OWNCLOUD_DB_TYPE" != 'pgsql' ]; then
		echo >&2 'error: missing MYSQL_PORT_3306_TCP environment variable'
		echo >&2 ' Did you forget to --link some_mysql_container:mysql ?'
		echo >&2 ' Or did you mistype "mysql" ?'
		exit 1
	fi

	# If database link of type "pgsql" is missing, exit. Also catches spelling errors.
	if [ -z "$POSTGRES_PORT_5432_TCP" -a "$OWNCLOUD_DB_TYPE" != 'mysql' ]; then
		echo >&2 'error: missing POSTGRES_PORT_5432_TCP environment variable'
		echo >&2 ' Did you forget to --link some_postgres_container:postgres ?'
		echo >&2 ' Or did you mistype "pgsql" ?'
		exit 1
	fi

	# If we're linked to MySQL, and we're using the root user, and our linked
	# container has a default "root" password set up and passed through... :)
	if [ "$OWNCLOUD_DB_USER" = 'root' ]; then
		if [ "$OWNCLOUD_DB_TYPE" = 'mysql' ]; then
			: ${OWNCLOUD_DB_PASSWORD:=$MYSQL_ENV_MYSQL_ROOT_PASSWORD}
		fi

		if [ "$OWNCLOUD_DB_TYPE" = 'pgsql' ]; then
			: ${OWNCLOUD_DB_PASSWORD:=$POSTGRES_ENV_POSTGRES_ROOT_PASSWORD}
		fi
	fi

	# If database password is missing, exit.
	if [ -z "$OWNCLOUD_DB_PASSWORD" ]; then
		echo >&2 'error: missing required OWNCLOUD_DB_PASSWORD environment variable'
		echo >&2 ' Did you forget to -e OWNCLOUD_DB_PASSWORD=... ?'
		echo >&2
		echo >&2 ' (Also of interest might be OWNCLOUD_DB_USER and OWNCLOUD_DB_NAME.)'
		exit 1
	fi
fi

# From now on a standalone php5-fpm instance is required.
# If fpm link of type "php5-fpm" is missing, exit.
if [ -z "$PHP5_FPM_PORT_9000_TCP_ADDR" ]; then
	echo >&2 'error: missing required PHP5_FPM_PORT_9000_TCP_ADDR environment variable'
	echo >&2 ' Did you forget to --link some_php5_fpm_container:php5_fpm ?'
	echo >&2 ' Unfortunatly a built-in instance is not supported at this time.'
	exit 1
fi

# TODO Detect if sql container is linked and override $OWNCLOUD_DB_TYPE accordingly, if still set to sqlite

# If no SSL certificate exists generate a self-signed one.
: ${OWNCLOUD_SSL_CERT:=$SSL_DIR/ssl.crt}
: ${OWNCLOUD_SSL_CERT_KEY:=$SSL_DIR/ssl.key}
if ! [ -f "$SSL_DIR/ssl.crt" -a -f "$SSL_DIR/ssl.key" ]; then
    expect <<EOF
	set send_slow {1 .1}
	proc send {ignore arg} {
	    sleep .1
	    exp_send -s -- \$arg
	}
	set timeout 60

	spawn openssl req -x509 -newkey rsa:2048 -keyout $SSL_DIR/ssl.key -out $SSL_DIR/ssl.crt -nodes -days XXX
	expect {
	    -exact "Country Name (2 letter code) \[AU\]:" { send -- ".\r"; exp_continue }
	    -exact "State or Province Name (full name) \[Some-State\]:" { send -- ".\r"; exp_continue }
	    -exact "Locality Name (eg, city) \[\]:" { send -- ".\r"; exp_continue }
	    -exact "Organization Name (eg, company) \[Internet Widgits Pty Ltd\]:" { send -- ".\r"; exp_continue }
	    -exact "Organizational Unit Name (eg, section) \[\]:" { send -- ".\r"; exp_continue }
	    -exact "Common Name (e.g. server FQDN or YOUR name) \[\]:" { sleep 1; send -- "docker-owncloud\r"; exp_continue }
	    -exact "Email Address \[\]:" { send -- ".\r"; exp_continue }
	}
EOF
        chown -R www-data:www-data $SSL_DIR
	chmod 600 $SSL_DIR/ssl.*
fi

# TODO handle and use a CA, preferably located outside container, so certificates can be revoked.

if ! [ -e $WEB_ROOT/index.php -a -e $WEB_ROOT/version.php ]; then
	echo >&2 "owncloud not found in $WEB_ROOT - copying now..."
	rsync -arxq $SRC_DIR/ $WEB_ROOT
	chown -R www-data:www-data $WEB_ROOT
	find "$WEB_ROOT" -type d -exec chmod 750 {} \;
	find "$WEB_ROOT" -type f -exec chmod 640 {} \;
	echo >&2 "Complete! owncloud has been successfully copied to $WEB_ROOT"
fi

# TODO handle ownCloud upgrades magically in the same way, but only if version.php's $OC_VersionString is less than /usr/src/owncloud/version.php's $OC_VersionString

# TODO Optional installation and config of php5 cache.

: ${OWNCLOUD_DOMAIN_NAME:=localhost}
: ${OWNCLOUD_FORCE_SSL:=true}

# Possible values: DEBUG, INFO, WARN, ERROR
: ${OWNCLOUD_LOG_LEVEL:=WARN}
# Possible values: debug, info, notice, warn, error, crit, alert, emerg
# Debug logging requires nginx container to be built with --with-debug (not in upstream)
: ${NGINX_LOG_LEVEL:=error}

set_config() {
    key="$1"
    value="$2"
    if [ "$config_file" = "$CONF_NGINX/nginx.conf" ]; then
        sed -ri "s|$key|$value|g" $config_file
    elif [ "$config_file" = "$CONF_OWNCLOUD/config.php" ]; then
        sed -ri "s|($key\S+ =>)[^,]*|\1 \"$value\"|g" $config_file
    elif [ "$config_file" = "$CONF_OWNCLOUD/autoconfig.php" ]; then
	sed -ri "s|($key\S+ =>)[^,]*|\1 \"$value\"|g" $config_file
    fi
}

config_file="$CONF_NGINX/nginx.conf"
set_config '%hostname%' "$OWNCLOUD_DOMAIN_NAME"
set_config '%ssl-crt%' "$OWNCLOUD_SSL_CERT"
set_config '%ssl-key%' "$OWNCLOUD_SSL_CERT_KEY"
set_config '%fpm-ip%' "$PHP5_FPM_PORT_9000_TCP_ADDR"
set_config '%log-level%' "$NGINX_LOG_LEVEL"

config_file="$CONF_OWNCLOUD/config.php"
set_config 'dbtype' "$OWNCLOUD_DB_TYPE"
set_config 'dbuser' "$OWNCLOUD_DB_USER"
set_config 'dbpassword' "$OWNCLOUD_DB_PASSWORD"
set_config 'dbname' "$OWNCLOUD_DB_NAME"
set_config 'forcessl' "$OWNCLOUD_FORCE_SSL"
set_config 'loglevel' "$OWNCLOUD_LOG_LEVEL"

config_file="$CONF_OWNCLOUD/autoconfig.php"
set_config 'dbtype' "$OWNCLOUD_DB_TYPE"
set_config 'dbuser' "$OWNCLOUD_DB_USER"
set_config 'dbpass' "$OWNCLOUD_DB_PASSWORD"
set_config 'dbname' "$OWNCLOUD_DB_NAME"

#TERM=dumb php -- "$OWNCLOUD_DB_HOST" "$OWNCLOUD_DB_USER" "$OWNCLOUD_DB_PASSWORD" "$OWNCLOUD_DB_NAME" <<'EOPHP'
#<?php
#// database might not exist, so let's try creating it (just to be safe)

#list($host, $port) = explode(':', $argv[1], 2);
#$mysql = new mysqli($host, $argv[2], $argv[3], '', (int)$port);

#if ($mysql->connect_error) {
#	file_put_contents('php://stderr', 'MySQL Connection Error: (' . $mysql->connect_errno . ') ' . $mysql->connect_error . "\n");
#	exit(1);
#}

#if (!$mysql->query('CREATE DATABASE IF NOT EXISTS `' . $mysql->real_escape_string($argv[4]) . '`')) {
#	file_put_contents('php://stderr', 'MySQL "CREATE DATABASE" Error: ' . $mysql->error . "\n");
#	$mysql->close();
#	exit(1);
#}

#$mysql->close();
#EOPHP

# TODO Implement UNIX socket setting in MariaDB container and maybe make pull request to MySQL, after testing that is. This TODO really belongs there, not here.

exec "$@"
