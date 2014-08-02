#!/bin/bash
set -e

# # Set default environment variables
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
		echo >&2 ' Did you forget to --link some_mysql_container:mysql ?'
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

if ! [ -e index.php -a -e version.php ]; then
	echo >&2 "ownCloud not found in $(pwd) - copying now..."
	rsync --archive --one-file-system --quiet --exclude='*.sh' --exclude='*.conf' --exclude='*.bz2*' --exclude='Dockerfile' /usr/src/owncloud/ ./
	chown -R www-data:www-data $(pwd) \
        find "$WEB_ROOT" -type d -exec chmod 750 {} \;
        find "$WEB_ROOT" -type f -exec chmod 640 {} \;
	echo >&2 "Complete! ownCloud has been successfully copied to $(pwd)"
fi

# TODO handle WordPress upgrades magically in the same way, but only if version.php's $OC_VersionString is less than /usr/src/owncloud/version.php's $OC_VersionString

# Common config edit function
set_config() {
    key="$1"
    value="$2"
    # Do a loop so sed can scale with number of files/options
    for i in $(find $CONF_DIR -type f); do
        sed -ri "s|\S*($key\s+).*|\1 $value|g" $i
    done
}

set_config 'dbtype' "$OWNCLOUD_DB_TYPE"
set_config 'dbname' "$OWNCLOUD_DB_NAME"
set_config 'dbuser' "$OWNCLOUD_DB_USER"
set_config 'dbpassword' "$OWNCLOUD_DB_PASSWORD"





# Set default values for configurations
: ${OWNCLOUD_DOMAIN_NAME:=cloud.example.com} # IDEA: Get default from hostname env var somehow?
: ${OWNCLOUD_SSL_CERT:=/etc/ssl/nginx/cloud.example.com.crt} # IDEA: Make this a shared volume in Dockerfile, so it can be stored.
: ${OWNCLOUD_SSL_CERT_KEY:=/etc/ssl/nginx/cloud.example.com.key}
: ${OWNCLOUD_DB_PASSWORD_SALT:=}
: ${OWNCLOUD_FORCE_SSL:=}
: ${OWNCLOUD_LOG_LEVEL:=}

# Apply default or user specified options to config files
set_config 'server_name' "$OWNCLOUD_DOMAIN_NAME" # Should default to hostname env var of container
set_config 'ssl_certificate' "$OWNCLOUD_SSL_CERT"
set_config 'ssl_certificate_key' "$OWNCLOUD_SSL_CERT_KEY"
set_config 'passwordsalt' "$OC_DB_PASSWORD_SALT" # Just like wordpress this could be set but randomly generated by default
set_config 'forcessl' "$OC_FORCE_SSL"
set_config 'loglevel' "$OC_LOG_LEVEL"


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

# FIX: Removed memcached as an option, since it should just be set to local anyways.
# So to implement this the default setting just has to be in config.php (maybe check for link, if needed)

# FIX: Just like wordpess check "$PHP_FPM_LISTEN" for optional unix socket setting.
# In any case setting should be taken from there and fall back to default. No user entry required.

# IDEA: If no ssl cert/key is supplied autogenerate one.
# Then if domain name is supplied rename them accordingly.

# IDEA: Check for php5-fpm env vars and duplicate the settings here.
# Then we could maybe in the future have an option for running php5-fpm in this container.

#opt_install # IDEA: Optional installation and config of php5 cache. Check wordpress entrypoint again.

exec "$@"
