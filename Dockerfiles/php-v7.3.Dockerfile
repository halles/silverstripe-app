# Extend from current stable php apache
FROM php:7.3-apache

# OS packages
RUN apt-get -y update && apt-get -y upgrade && apt-get install -y \
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
    --no-install-recommends && rm -r /var/lib/apt/lists/*

RUN \
    # Installs SSPAK for SilverStripe
    # https://github.com/silverstripe/sspak
    curl -sS https://silverstripe.github.io/sspak/install | php -- /usr/local/bin; \
    # Makes binaries specified by composer accessible to bash
    echo 'PATH=$PATH:/var/www/vendor/bin' >> /etc/bash.bashrc; \
    # Changes user id of www-data to 1000 for permissions and shares
    # compatibility with other machines
    usermod -u 1000 www-data; \
    groupmod -g 1000 www-data; \
    # Removes files we won't use from /var/www
    rm -rvf /var/www/*; \
    # Gives ownership of /var/solr to www-data to allow index creation
    mkdir /var/solr && chown -R www-data:www-data /var/solr;

# PHP Extensions and Config
RUN docker-php-ext-configure intl \
    && docker-php-ext-configure gd --with-png-dir=/usr/lib --with-jpeg-dir=/usr/lib --with-webp-dir=/usr/lib
RUN docker-php-ext-install \
    pdo_mysql \
    mysqli \
    intl \
    gd \
    bcmath
COPY ["./conf/php/", "/usr/local/etc/php/"]

# Composer binary
RUN curl -sS https://getcomposer.org/installer | php -- --filename=composer --install-dir=/usr/local/bin
RUN composer -V

# Install node
RUN curl -sL https://deb.nodesource.com/setup_8.x | bash -
RUN apt-get install --no-install-recommends -y \
        nodejs \
        npm

# Update npm and yarn
RUN npm install -g npm yarn

# Apache Configuration
COPY ["./conf/apache2/docker.conf", "/etc/apache2/sites-enabled/000-default.conf"]
RUN \
    # Generates default SSL certificates
    make-ssl-cert generate-default-snakeoil; \
    # Adds both runtime users to the ssl-cert group
    usermod --append --groups ssl-cert root; \
    usermod --append --groups ssl-cert www-data;\
    # Enables apache modules
    a2enmod headers rewrite ssl