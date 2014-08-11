FROM nginx:latest
MAINTAINER Patrik Nilsson <asavartzeth@gmail.com>

# Let the conatiner know that there is no tty
ENV DEBIAN_FRONTEND noninteractive

# Environment variables
ENV WEB_ROOT /usr/local/nginx/html
ENV SRC_DIR /usr/src/owncloud
ENV SSL_DIR /etc/ssl/owncloud
ENV CONF_NGINX /etc
ENV CONF_PHP5 /etc/php5/fpm
ENV CONF_OWNCLOUD /usr/local/nginx/html/config

# All our dependencies, in alphabetical order (to ease maintenance)
RUN apt-get update && apt-get -o Dpkg::Options::="--force-confold" install -y --no-install-recommends \
        php5-curl \
        php5-fpm \
        php5-gd \
        php5-intl \
        php5-imagick \
        php5-ldap \
        php5-mcrypt \
        php5-mhash \
        php5-mysql \
        php5-pgsql \
        php5-sqlite
# Extra functionality
# Try to change libav-tools to libavcodec55
# Would appreciate if owncloud devs were a bit more specific here
# May make a version without some of the bloat in future
RUN apt-get install -y --no-install-recommends \
        libav-tools \
        libreoffice \
        smbclient

# Add application files
ADD . /usr/src/owncloud
WORKDIR /usr/src/owncloud

# Extract ownCloud archive
RUN tar --strip-components=1 -xf owncloud-*.tar.bz2

# Find config files and edit
RUN find "$CONF_OWNCLOUD" -type f -exec sed -ri ' \
    s|(\S*logfile\S\s+=>).*|\1 "/proc/self/fd/3",|g; \
' '{}' ';'

WORKDIR /usr/local/nginx/html

VOLUME ["/etc/ssl/owncloud"]
VOLUME ["/usr/local/nginx/html/data" "/usr/local/nginx/html/config"]

ADD docker-entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 80 443
CMD ["nginx"]
