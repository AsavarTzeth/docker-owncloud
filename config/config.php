<?php

$CONFIG = array(

/* Type of database, can be sqlite, mysql or pgsql */
"dbtype" => "sqlite",

/* Name of the ownCloud database */
"dbname" => "owncloud",

/* User to access the ownCloud database */
"dbuser" => "root",

/* Password to access the ownCloud database */
"dbpassword" => "",

/* Host running the ownCloud database. To specify a port use "HOSTNAME:####"; to specify a unix sockets use "localhost:/path/to/socket". */
"dbhost" => "127.0.0.1:9000",

/* Define the salt used to hash the user passwords. All your user passwords are lost if you lose this string. */
"passwordsalt" => "",

/* Force use of HTTPS connection (true = use HTTPS) */
"forcessl" => true

/* memcached servers (Only used when xCache, APC and APCu are absent.) */
"memcached_servers" => array(
	// hostname, port and optional weight. Also see:
	// http://www.php.net/manual/en/memcached.addservers.php
	// http://www.php.net/manual/en/memcached.addserver.php
	array('localhost', 11211),
	//array('other.host.local', 11211),
),

/* File for the owncloud logger to log to, (default is ownloud.log in the data dir) */
"logfile" => "",

/* Loglevel to start logging at. 0=DEBUG, 1=INFO, 2=WARN, 3=ERROR (default is WARN) */
"loglevel" => "",

// PREVIEW
'enable_previews' => true,
/* the max width of a generated preview, if value is null, there is no limit */
/* this could optionally be used if I decide I want a setting for installing libreoffice at runtime */

);
