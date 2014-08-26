#How to use this image:#

    sudo docker run -d --name some-owncloud --link some-php5-fpm:php5_fpm --link some-mysql:mysql asavartzeth/owncloud

The example above will run the container, but will not protect valuable data. Please read the Volumes section bellow, then use the detailed step by step guide, if you need it.

*Note! Currenlty I have opted for a sepperate [php5-fpm](https://registry.hub.docker.com/u/asavartzeth/php5-fpm/) instance, but this will be optional in the future.*

##Configuration##

The following environment variables are also honored for configuring your ownCloud instance:

- -e `OWNCLOUD_DOMAIN_NAME=...` (defaults to localhost)
- -e `OWNCLOUD_DB_TYPE=...` (defaults to sqlite)  
Possible Values: sqlite, mysql, pgsql
- -e `OWNCLOUD_DB_NAME=...` (defaults to owncloud)
- -e `OWNCLOUD_DB_USER=...` (defaults to root)
- -e `OWNCLOUD_DB_PASSWORD=...` (defaults to the value of the MYSQL_ROOT_PASSWORD environment variable from the linked mysql/mariadb container)
Alternative value: localhost:/var/run/php5-fpm.sock
- -e `OWNCLOUD_FORCE_SSL=...` (defaults to true (nginx conf is not tested with false yet) )
- -e `OWNCLOUD_LOG_LEVEL=...` (defaults to WARN)  
Possible Values: DEBUG, INFO, WARN, ERROR
- -e `OWNCLOUD_SSL_CERT=...` (defaults to /etc/ssl/nginx/ssl.crt) (if unsure, leave be)
- -e `OWNCLOUD_SSL_KEY=...` (defaults to /etc/ssl/nginx/ssl.key) (if unsure, leave be)

If the `OWNCLOUD_DB_NAME` specified does not already exist in the given MySQL/MariaDB container, it will be created automatically upon container startup, provided that the `OWNCLOUD_DB_USER` specified has the necessary permissions to create it.

Regarding use cases for the `OWNCLOUD_SSL_*` variables. You might have a wildcard ssl cert you wish to share between containers. This could be stored in a volume, a data volume container or even the host. In any case these variables will give you the freedom to set things to fit your needs.

##Volumes##

Currently the recommended way of storing this data is with the use of data volume containers [(see Docker documentation)](https://docs.docker.com/userguide/dockervolumes/).

The prefered way of doing this is with another instance, in this case **asavartzeth/owncloud**. However, at this time any such attempts will fail, unless you are willing make this fully functional and connected to SQL as well. Because of this I recommend using something like **tianon/true** at this time. It should work well with all, or most, of my builds.

In the future I might put in an `OWNCLOUD_DATA_TRUE` variable, or similar that you could simply set and the container would ignore any additional setup and run in a special data volume container mode.

##Adding a SSL certificate##

By default the entrypoint script will create a self-signed certificate and place it in */etc/ssl/nginx/*. You may change the location to fit your need with the honored environment variables listed above.

Currently the best way of adding a cert & key to your container is with a Dockerfile, using the docker ADD instruction. This requires full knowledge of Dockerfiles and is not ideal for some users. I would prefer it if docker.io added support for running "docker add" on the command line.

If anyone have a user-friendly way of adding files to already built and running containers, please share it.

##Step by Step##

First make sure you have tianon/true on your system.

    sudo docker pull tianon/true:latest

Then create a volume-only container.

    sudo docker run -d -v /usr/local/nginx/ssl -v /usr/local/nginx/html/owncloud/data -v /usr/local/nginx/html/owncloud/config --name oc_data tianon/true

Lastly use the --volumes-from flag to mount the volumes in the owncloud container.

    sudo docker run -d --volumes-from oc_data --name some-owncloud --link some-php5-fpm:php5_fpm --link some-mysql:mysql asavartzeth/owncloud

Now your setup will store all critical files in the oc_data (or whatever you name it) container.

