FROM nginx:latest
MAINTAINER Patrik Nilsson <asavartzeth@gmail.com>

# Let the conatiner know that there is no tty
ENV DEBIAN_FRONTEND noninteractive

# Environment variables
ENV WEB_ROOT /usr/local/nginx/html/owncloud
ENV SRC_DIR /usr/src/owncloud
ENV SSL_DIR /usr/local/nginx/ssl
ENV CONF_NGINX /etc
ENV CONF_PHP5 /etc/php5/fpm
ENV CONF_OWNCLOUD /usr/local/nginx/html/owncloud/config

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
	php5-sqlite \
	rsync
# Extra functionality
# Try to change libav-tools to libavcodec55
# Would appreciate if owncloud devs were a bit more specific here
# May make a version without some of the bloat in future
RUN apt-get install -y --no-install-recommends \
        libav-tools \
        libreoffice \
        smbclient

WORKDIR /usr/src/owncloud
ADD . /usr/src/owncloud
RUN rm $CONF_NGINX/nginx.conf && \
    tar --strip-components=1 -xf owncloud-*.tar.bz2

ADD docker-entrypoint.sh /entrypoint.sh
RUN chmod 744 /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 80 443
CMD ["nginx"]
