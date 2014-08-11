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
		echo >&2 'error: missing MYSQL_PORT_3306_TCP environment variable'
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

# TODO Detect if sql container is linked and override $OWNCLOUD_DB_TYPE accordingly, if still set to sqlite

# If we're linked to PHP5-FPM, get settings from there, else set defaults locally.
if [ -n "$PHP5_FPM_PORT_9000_TCP" ]; then
    : ${PHP5_FPM_MEMORY_LIMIT:=$PHP5_FPM_ENV_PHP5_FPM_MEMORY_LIMIT}
    : ${PHP5_FPM_LOG_LEVEL:=$PHP5_FPM_ENV_PHP5_FPM_LOG_LEVEL}
    : ${PHP5_FPM_LISTEN:=$PHP5_FPM_ENV_PHP5_FPM_LISTEN}
elif
    : ${PHP5_FPM_MEMORY_LIMIT:=128M}
    : ${PHP5_FPM_LOG_LEVEL:=notice}
    : ${PHP5_FPM_LISTEN:=127.0.0.1:9000}
fi

# TODO check value "$PHP5_FPM_LISTEN" in case unix socket is used. If it is edit nginx.conf accordingly.

: ${OWNCLOUD_SSL_CERT:=/etc/ssl/nginx/ssl.crt}
: ${OWNCLOUD_SSL_CERT_KEY:=/etc/ssl/nginx/ssl.key}

# If no SSL certificate exists generate a self-signed one.
if [ -f "$SSL_DIR/ssl.crt" -a -f "$SSL_DIR/ssl.key" ]; then
    openssl req -x509 -newkey rsa:2048 -keyout $SSL_DIR/ssl.key -out $SSL_DIR/ssl.crt -nodes -days XXX
    chmod 600 $SSL_DIR/ssl.*
fi

# TODO handle and use a CA, preferably located outside container, so certificates can be revoked.

if ! [ -e index.php -a -e version.php ]; then
	echo >&2 "ownCloud not found in $WEB_ROOT - copying now..."
	rsync --archive --one-file-system --quiet --exclude='*.sh' --exclude='*.conf' --exclude='*.bz2*' --exclude='Dockerfile' $SRC_DIR $WEB_ROOT
	chown -R www-data:www-data $WEB_DIR \
        find "$WEB_ROOT" -type d -exec chmod 750 {} \;
        find "$WEB_ROOT" -type f -exec chmod 640 {} \;
	echo >&2 "Complete! ownCloud has been successfully copied to $WEB_ROOT"
fi

# TODO handle ownCloud upgrades magically in the same way, but only if version.php's $OC_VersionString is less than /usr/src/owncloud/version.php's $OC_VersionString

# If $CONF_DIR/nginx.conf is missing, copy from /usr/src/owncloud
if ! [ -e $CONF_NGINX/nginx.conf ]; then
    echo >&2 "nginx.conf not found in $CONF_NGINX - copying now..."
    cp -a $SRC_DIR/nginx.conf $CONF_NGINX/
fi

# TODO Optional installation and config of php5 cache.

: ${OWNCLOUD_DOMAIN_NAME:=localhost}
: ${OWNCLOUD_FORCE_SSL:=true}
: ${OWNCLOUD_LOG_LEVEL:=WARN}

set_config() {
    key="$1"
    value="$2"
    if [ "$config_file" = "$CONF_NGINX/nginx.conf" ]; then
        sed -ri "s|\S*($key)\s+[^;]*|\1 $value|g" $config_file
    elif [ "$config_file" = "$CONF_PHP5" ]; then
        for i in $(find $CONF_PHP5 -type f); do
            sed -ri "s|\S*($key\s+=).*|\1 $value|g" $i
        done
    elif [ "$config_file" = "$CONF_OWNCLOUD/config.php" ]; then
        sed -ri "s|\S*($key\S+ =>)[^,]*|\1 \"$value\"|g" $config_file
    fi
}

config_file="$CONF_NGINX/nginx.conf"
set_config 'server_name' "$OWNCLOUD_DOMAIN_NAME"
set_config 'ssl_certificate' "$OWNCLOUD_SSL_CERT"
set_config 'ssl_certificate_key' "$OWNCLOUD_SSL_CERT_KEY"

config_file="$CONF_PHP5"
set_config 'memory_limit' "$PHP5_FPM_MEMORY_LIMIT"
set_config 'log_level' "$PHP5_FPM_LOG_LEVEL"
set_config 'listen' "$PHP5_FPM_LISTEN"

config_file="$CONF_OWNCLOUD/config.php"
set_config 'dbtype' "$OWNCLOUD_DB_TYPE"
set_config 'dbuser' "$OWNCLOUD_DB_USER"
set_config 'dbpassword' "$OWNCLOUD_DB_PASSWORD"
set_config 'dbname' "$OWNCLOUD_DB_NAME"
set_config 'forcessl' "$OWNCLOUD_FORCE_SSL"
set_config 'loglevel' "$OWNCLOUD_LOG_LEVEL"

TERM=dumb php -- "$OWNCLOUD_DB_HOST" "$OWNCLOUD_DB_USER" "$OWNCLOUD_DB_PASSWORD" "$OWNCLOUD_DB_NAME" <<'EOPHP'
<?php
// database might not exist, so let's try creating it (just to be safe)

list($host, $port) = explode(':', $argv[1], 2);
$mysql = new mysqli($host, $argv[2], $argv[3], '', (int)$port);

if ($mysql->connect_error) {
	file_put_contents('php://stderr', 'MySQL Connection Error: (' . $mysql->connect_errno . ') ' . $mysql->connect_error . "\n");
	exit(1);
}

if (!$mysql->query('CREATE DATABASE IF NOT EXISTS `' . $mysql->real_escape_string($argv[4]) . '`')) {
	file_put_contents('php://stderr', 'MySQL "CREATE DATABASE" Error: ' . $mysql->error . "\n");
	$mysql->close();
	exit(1);
}

$mysql->close();
EOPHP

# TODO Implement UNIX socket setting in MariaDB container and maybe make pull request to MySQL, after testing that is. This TODO really belongs there, not here.

exec "$@"
