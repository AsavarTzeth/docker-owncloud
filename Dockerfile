FROM nginx:latest
MAINTAINER Patrik Nilsson <asavartzeth@gmail.com>

# Let the conatiner know that there is no tty
ENV DEBIAN_FRONTEND noninteractive

# Common environment variables
ENV CONF_DIR /usr/local/nginx/conf
ENV DATA_DIR /usr/local/nginx/html/data

# Container specific environment variables
ENV WEB_ROOT /usr/local/nginx/html
ENV OC_CONF_DIR /usr/local/nginx/html/config

# All our dependencies, in alphabetical order (to ease maintenance)
RUN rm /etc/mime.types \
&& apt-get update && apt-get install -y --no-install-recommends \
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
RUN apt-get install -y --no-install-recommends\
        libav-tools \
        libreoffice \
        smbclient

# Add application files
ADD . /usr/src/owncloud
WORKDIR /usr/src/owncloud

# Install new nginx.conf
RUN mkdir -p $CONF_DIR \
        && rm /etc/nginx.conf \
        && cp nginx.conf $CONF_DIR/nginx.conf \
        && ln -s $CONF_DIR/nginx.conf /etc/nginx.conf

# Install application
RUN tar --strip-components=1 -xf owncloud-*.tar.bz2 -C "$WEB_ROOT" \
        && chown -R www-data:www-data "$WEB_ROOT" \
        && find "$WEB_ROOT" -type d -exec chmod 750 {} \; \
        && find "$WEB_ROOT" -type f -exec chmod 640 {} \;

# Find config files and edit
RUN find "$OC_CONF_DIR" -type f -exec sed -ri ' \
    s|(\S*logfile\S\s+=>).*|\1 "/proc/self/fd/3",|g; \
' '{}' ';'

WORKDIR /usr/local/nginx/html

ADD docker-entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 80 443
CMD ["nginx"]