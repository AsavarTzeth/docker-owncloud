FROM asavartzeth/nginx
MAINTAINER Patrik Nilsson <asavartzeth@gmail.com>

# Let the conatiner know that there is no tty
ENV DEBIAN_FRONTEND noninteractive

# Runtime dependencies
# (packages are listed alphabetically to ease maintenence)
RUN apt-get update && apt-get -o Dpkg::Options::="--force-confold" install -y --no-install-recommends \
	expect \
        libav-tools \
        libreoffice \
	openssl \
	rsync \
        smbclient

# See https://owncloud.org/owncloud.asc
RUN gpg --keyserver pgp.mit.edu --recv-key F6978A26

ENV WEB_ROOT /usr/local/nginx/html
ENV OWNCLOUD_VERSION 7.0.2

# Build dependencies
# (packages are listed alphabetically to ease maintenence)
RUN buildDeps=" \
	bzip2 \
	ca-certificates \
	curl \
	"; \
	apt-get update && apt-get install -y --no-install-recommends $buildDeps && rm -rf /var/lib/apt/lists/* \
	&& curl -SL "https://download.owncloud.org/community/owncloud-$OWNCLOUD_VERSION.tar.bz2" -o owncloud.tar.bz2 \
	&& curl -SL "https://download.owncloud.org/community/owncloud-$OWNCLOUD_VERSION.tar.bz2.asc" -o owncloud.tar.bz2.asc \
	&& gpg --verify owncloud.tar.bz2.asc \
	&& mkdir -p $WEB_ROOT -p $SSL_DIR \
	&& tar -xvf owncloud.tar.bz2 -C /usr/src/ \
	&& rm owncloud.tar.bz2* \
	&& find "$WEB_ROOT" -type d -exec chmod 750 {} \; \
	&& find "$WEB_ROOT" -type f -exec chmod 640 {} \; \
	&& apt-get purge -y --auto-remove $buildDeps

ADD config /usr/src/owncloud/config/
ADD nginx.conf /etc/
ADD docker-entrypoint.sh /entrypoint.sh

ENV SRC_DIR /usr/src/owncloud

RUN chown -R www-data:www-data $WEB_ROOT \
	&& chmod -R 640 $SRC_DIR/config \
	&& chmod 744 /entrypoint.sh

# Put low, so changes do not require rebuild
ENV SSL_DIR /usr/local/nginx/ssl
ENV CONF_NGINX /etc
ENV CONF_PHP5 /etc/php5/fpm
ENV CONF_OWNCLOUD /usr/local/nginx/html/config

VOLUME /usr/local/nginx/html

WORKDIR /usr/local/nginx/html

ENTRYPOINT ["/entrypoint.sh"]

# TODO USER www-data

EXPOSE 80 443
CMD ["nginx"]
