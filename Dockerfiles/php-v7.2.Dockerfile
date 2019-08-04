# Extend from current stable php apache
FROM php:7.2-apache

# Extra Repositories
RUN curl -sL https://deb.nodesource.com/setup_8.x | bash -

# OS packages
RUN apt-get -y update; \
    apt-get -y upgrade;\
    apt-get install -y --no-install-recommends \
        ssl-cert \
        mariadb-client \
        zlib1g-dev \
        libicu-dev \
        libpng-dev \
        libjpeg-dev \
        libwebp-dev \
        gnupg \
        build-essential \
        zip \
        unzip \
        curl \
        git \
        ssh \
        jq \
        nano \
        vim \
        apt-utils \
        net-tools \
        iputils-ping \
        iproute2 \
        nodejs \
        npm; \
    rm -r /var/lib/apt/lists/*

RUN \
    # Installs SSPAK for SilverStripe
    # https://github.com/silverstripe/sspak
    curl -sS https://silverstripe.github.io/sspak/install | php -- /usr/local/bin; \
    # Composer binary
    curl -sS https://getcomposer.org/installer | php -- --filename=composer --install-dir=/usr/local/bin; \
    # Makes binaries specified by composer accessible to bash
    echo 'PATH=$PATH:/var/www/vendor/bin' >> /etc/bash.bashrc;

RUN \
    # Changes user id of www-data to 1000 for permissions and shares
    # compatibility with other machines
    usermod -u 1000 www-data; \
    groupmod -g 1000 www-data; \
    # Removes files we won't use from /var/www
    rm -rvf /var/www/*; \
    # Gives ownership of /var/solr to www-data to allow index creation
    mkdir /var/solr && chown -R www-data:www-data /var/solr;

# Installs PHP Extensions
RUN docker-php-ext-configure intl \
    && docker-php-ext-configure gd --with-png-dir=/usr/lib --with-jpeg-dir=/usr/lib --with-webp-dir=/usr/lib
RUN docker-php-ext-install \
        pdo_mysql \
        mysqli \
        intl \
        gd \
        bcmath; \
    pecl install xdebug; \
    docker-php-ext-enable xdebug;

# Update npm and yarn
RUN npm install -g npm yarn

# PHP Configuration
COPY ["./conf/php/php.ini", "/usr/local/etc/php/php.ini"]
COPY ["./conf/php/docker-php-ext*", "/usr/local/etc/php/conf.d/"]

# Apache Configuration
COPY ["./conf/apache2/docker.conf", "/etc/apache2/sites-enabled/000-default.conf"]
RUN \
    # Generates default SSL certificates
    make-ssl-cert generate-default-snakeoil; \
    # Generates SSL certificates for localhost
    cat /etc/ssl/openssl.cnf > /tmp/SSL_SAN_config; \
    printf "[SAN]\nsubjectAltName=DNS:localhost" >> /tmp/SSL_SAN_config; \
    openssl \
        req -newkey rsa:2048 -x509 -nodes \
        -keyout /etc/ssl/private/localhost.key \
        -new \
        -out /etc/ssl/certs/localhost.cert \
        -subj /CN=localhost \
        -reqexts SAN \
        -extensions SAN \
        -config /tmp/SSL_SAN_config \
        -sha256 -days 3650; \
    # Adds both runtime users to the ssl-cert group
    usermod --append --groups ssl-cert root; \
    usermod --append --groups ssl-cert www-data;\
    # Enables apache modules
    a2enmod headers rewrite ssl