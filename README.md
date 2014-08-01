#How to use this image:#

    docker run --name some-owncloud --link some-owncloud:owncloud -d asavartzeth/owncloud

The following environment variables are also honored for configuring your ownCloud instance:

- -e `OWNCLOUD_DOMAIN_NAME=...` (defaults to container hostname)
- -e `OWNCLOUD_SSL_CERT=...` (defaults to self-signed cert, generated at runtime)
- -e `OWNCLOUD_SSL_KEY=...` (defaults to self-generated key, generated at runtime)
- -e `OWNCLOUD_DB_TYPE=...` (defaults to sqlite)
- -e `OWNCLOUD_DB_NAME=...` (defaults to owncloud)
- -e `OWNCLOUD_DB_USER=...` (defaults to root)
- -e `OWNCLOUD_DB_PASSWORD=...` (defaults to the value of the MYSQL_ROOT_PASSWORD environment variable from the linked mysql/mariadb container)
Alternative value: localhost:/var/run/php5-fpm.sock
- -e `OWNCLOUD_DB_PASSWORD_SALT=...` (default to unique random SHA1s)
- -e `OWNCLOUD_FORCE_SSL=...` (defaults to true (nginx conf is not tested with false yet) )
- -e `OWNCLOUD_LOG_LEVEL=...` (defaults to WARN)  
Possible Values: 0=DEBUG, 1=INFO, 2=WARN, 3=ERROR

If the `OWNCLOUD_DB_NAME` specified does not already exist in the given MySQL/MariaDB container, it will be created automatically upon container startup, provided that the `OWNCLOUD_DB_USER` specified has the necessary permissions to create it.

##Volumes:##

