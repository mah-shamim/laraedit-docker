FROM ubuntu:24.04
LABEL maintainer="MD ARIFUL HAQUE <mah.shamim@gmail.com>"

# Set environment variables
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    DEBIAN_FRONTEND=noninteractive \
    APP_NAME=app \
    APP_EMAIL=mah.shamim@gmail.com.com \
    APP_DOMAIN=app.dev \
    DB_PASS=secret

# Set root password and install base packages
RUN echo 'root:root' | chpasswd && \
    apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
        apt-utils \
        software-properties-common \
        curl \
        build-essential \
        dos2unix \
        gcc \
        git \
        libmcrypt4 \
        libpcre3-dev \
        python3-pip \
        wget \
        zip \
        unzip \
        unattended-upgrades \
        whois \
        vim \
        debconf-utils \
        libnotify-bin \
        locales \
        cron \
        libpng-dev \
        memcached \
        make \
        nodejs \
        nginx \
        openssh-server \
        redis-server \
        supervisor \
        sqlite3 \
        libsqlite3-dev \
        mysql-server \
        libmysqlclient-dev \
        libffi-dev && \
    # Install PHP 8.3 and extensions
    add-apt-repository ppa:ondrej/php -y && \
    apt-get update && \
    apt-get install -y \
        php8.3 \
        php8.3-amqp \
        php8.3-ast \
        php8.3-bcmath \
        php8.3-bz2 \
        php8.3-cgi \
        php8.3-cli \
        php8.3-common \
        php8.3-curl \
        php8.3-dba \
        php8.3-dev \
        php8.3-ds \
        php8.3-enchant \
        php8.3-exif \
        php8.3-fpm \
        php8.3-ffi \
        php8.3-fileinfo \
        php8.3-ftp \
        php8.3-gd \
        php8.3-gearman \
        php8.3-gmp \
        php8.3-gnupg \
        php8.3-gettext \
        php8.3-igbinary \
        php8.3-imagick \
        php8.3-imap \
        php8.3-interbase \
        php8.3-intl \
        php8.3-ldap \
        php8.3-mailparse \
        php8.3-maxminddb \
        php8.3-mbstring \
        php8.3-memcache \
        php8.3-memcached \
        php8.3-mongodb \
        php8.3-msgpack \
        php8.3-mysql \
        php8.3-oauth \
        php8.3-odbc \
        php8.3-opcache \
        php8.3-pgsql \
        php8.3-phpdbg \
        php8.3-pspell \
        php8.3-psr \
        php8.3-raphf \
        php8.3-readline \
        php8.3-redis \
        php8.3-rrd \
        php8.3-smbclient \
        php8.3-snmp \
        php8.3-soap \
        php8.3-solr \
        php8.3-sqlite3 \
        php8.3-ssh2 \
        php8.3-sybase \
        php8.3-tidy \
        php8.3-uopz \
        php8.3-uploadprogress \
        php8.3-uuid \
        php8.3-xdebug \
        php8.3-xml \
        php8.3-xmlrpc \
        php8.3-xsl \
        php8.3-yac \
        php8.3-yaml \
        php8.3-zip \
        php8.3-zmq && \
    # Note: Some packages like php-json, php8.3-mcrypt, php8.3-tideways, php8.3-pinba may not be available
    # Create PHP-FPM directory
    mkdir -p /run/php/ && chown -Rf www-data:www-data /run/php && \
    # Install Composer
    curl -sS https://getcomposer.org/installer | php && \
    mv composer.phar /usr/local/bin/composer && \
    printf "\nPATH=\"~/.composer/vendor/bin:\$PATH\"\n" | tee -a ~/.bashrc && \
    # Set locale
    echo "LC_ALL=en_US.UTF-8" >> /etc/default/locale && \
    locale-gen en_US.UTF-8 && \
    ln -sf /usr/share/zoneinfo/UTC /etc/localtime

# Setup bash aliases
COPY .bash_aliases /root/

# Configure Nginx
COPY homestead /etc/nginx/sites-available/
RUN rm -rf /etc/nginx/sites-available/default \
    /etc/nginx/sites-enabled/default && \
    ln -fs /etc/nginx/sites-available/homestead /etc/nginx/sites-enabled/homestead && \
    sed -i 's/keepalive_timeout\s*65/keepalive_timeout 2/' /etc/nginx/nginx.conf && \
    sed -i 's/keepalive_timeout 2/keepalive_timeout 2;\n\tclient_max_body_size 100m;/' /etc/nginx/nginx.conf && \
    echo "daemon off;" >> /etc/nginx/nginx.conf && \
    chown -Rf www-data:www-data /var/www/html/ && \
    sed -i 's/worker_processes\s*1/worker_processes 5/' /etc/nginx/nginx.conf

VOLUME ["/var/www/html/app", "/var/cache/nginx", "/var/log/nginx"]

# Configure PHP
COPY fastcgi_params /etc/nginx/
RUN for ini in /etc/php/8.3/cli/php.ini /etc/php/8.3/fpm/php.ini; do \
        sed -i 's/error_reporting\s*=\s*.*/error_reporting = E_ALL/' $ini && \
        sed -i 's/display_errors\s*=\s*.*/display_errors = On/' $ini && \
        sed -i 's/;date.timezone\s*=\s*.*/date.timezone = UTC/' $ini && \
        sed -i 's/upload_max_filesize\s*=\s*.*/upload_max_filesize = 100M/' $ini && \
        sed -i 's/post_max_size\s*=\s*.*/post_max_size = 100M/' $ini; \
    done && \
    sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/' /etc/php/8.3/fpm/php.ini && \
    # Disable auto-loaded extensions from mods-available
    find /etc/php/8.3/mods-available/ -name "*.ini" -exec sed -i 's/^extension=/;extension=/' {} \; && \
    find /etc/php/8.3/mods-available/ -name "*.ini" -exec sed -i 's/^zend_extension=/;zend_extension=/' {} \; && \
    # Selectively enable only needed extensions in FPM
    mkdir -p /etc/php/8.3/conf.d && \
    echo "extension=mongodb.so" > /etc/php/8.3/conf.d/20-mongodb.ini && \
    echo "extension=pgsql.so" > /etc/php/8.3/conf.d/20-pgsql.ini && \
    echo "extension=sqlite3.so" > /etc/php/8.3/conf.d/20-sqlite3.ini && \
    echo "zend_extension=xdebug.so" > /etc/php/8.3/conf.d/20-xdebug.ini && \
    # Configure PHP-FPM
    sed -i 's/;daemonize\s*=\s*yes/daemonize = no/' /etc/php/8.3/fpm/php-fpm.conf && \
    sed -i 's/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/' /etc/php/8.3/fpm/pool.d/www.conf && \
    sed -i 's/pm.max_children\s*=\s*5/pm.max_children = 9/' /etc/php/8.3/fpm/pool.d/www.conf && \
    sed -i 's/pm.start_servers\s*=\s*2/pm.start_servers = 3/' /etc/php/8.3/fpm/pool.d/www.conf && \
    sed -i 's/pm.min_spare_servers\s*=\s*1/pm.min_spare_servers = 2/' /etc/php/8.3/fpm/pool.d/www.conf && \
    sed -i 's/pm.max_spare_servers\s*=\s*3/pm.max_spare_servers = 4/' /etc/php/8.3/fpm/pool.d/www.conf && \
    sed -i 's/pm.max_requests\s*=\s*500/pm.max_requests = 200/' /etc/php/8.3/fpm/pool.d/www.conf && \
    sed -i 's/;listen.mode\s*=\s*0660/listen.mode = 0750/' /etc/php/8.3/fpm/pool.d/www.conf && \
    # Comment out all disabled extensions
    find /etc/php/8.3/cli/conf.d/ -name "*.ini" -exec sed -i 's/^\(\s*\)\(extension\)/\1;\2/' {} \;

# Configure SSH
RUN mkdir -p /var/run/sshd && \
    sed -ri 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# Configure MySQL
RUN echo "[mysqld]" >> /etc/mysql/my.cnf && \
    echo "default_password_lifetime = 0" >> /etc/mysql/my.cnf && \
    sed -i 's/^bind-address\s*=.*/bind-address = 0.0.0.0/' /etc/mysql/my.cnf && \
    sed -i 's/^bind-address\s*=.*/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf

VOLUME ["/var/lib/mysql"]

# Install Laravel installer
RUN composer global require "laravel/installer"

# Install Supervisor
RUN mkdir -p /var/log/supervisor
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

VOLUME ["/var/log/supervisor"]

# Clean up
RUN apt-get remove --purge -y software-properties-common && \
    apt-get autoremove -y && \
    apt-get clean && \
    apt-get autoclean && \
    echo -n > /var/lib/apt/extended_states && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /usr/share/man/?? /usr/share/man/??_*

# Expose ports
EXPOSE 22 80 443 3306 6379

# Set entrypoint and command
ENTRYPOINT ["/bin/bash", "-c"]
CMD ["/usr/bin/supervisord"]
