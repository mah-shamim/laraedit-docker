FROM ubuntu:latest
LABEL maintainer="MD ARIFUL HAQUE <mah.shamim@gmail.com>"

# Set environment variables
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    DEBIAN_FRONTEND=noninteractive \
    APP_NAME=app \
    APP_EMAIL=app@example.com \
    APP_DOMAIN=app.dev

# Set root password to root, format is 'user:password'.
RUN echo 'root:root' | chpasswd && \
    # upgrade the container \
    apt-get update && apt-get upgrade -y && \
    # install some prerequisites
    apt-get update && apt-get install -y --no-install-recommends apt-utils software-properties-common curl \
    build-essential dos2unix gcc git libmcrypt4 libpcre3-dev python3-pip wget zip \
    unattended-upgrades whois vim debconf-utils libnotify-bin locales \
    cron libpng-dev unzip memcached make nodejs nginx openssh-server redis-server supervisor \
    sqlite3 libsqlite3-dev mysql-server libmysqlclient-dev libffi-dev && \
    # install php8.3
    add-apt-repository ppa:ondrej/php && \
    apt-get install -y php8.3 php8.3-amqp php8.3-ast php8.3-bcmath php8.3-bz2 php8.3-cgi php8.3-cli php8.3-common php8.3-curl \
    php8.3-dba php8.3-dev php8.3-ds php8.3-enchant php8.3-exif \
    php8.3-facedetect php8.3-fpm php8.3-ffi php8.3-fileinfo php8.3-ftp \
    php8.3-gd php8.3-gearman php8.3-gmp php8.3-gnupg php8.3-gettext \
    php8.3-igbinary php8.3-imagick php8.3-imap php8.3-interbase php8.3-intl php-json \
    php8.3-ldap php8.3-libvirt-php php8.3-mailparse php8.3-maxminddb php8.3-mbstring \
    php8.3-mcrypt php8.3-memcache php8.3-memcached php8.3-mongodb php8.3-msgpack php8.3-mysql \
    php8.3-oauth php8.3-odbc php8.3-opcache \
    php8.3-pgsql php8.3-phpdbg php8.3-pinba php8.3-ps php8.3-pspell php8.3-psr \
    php8.3-raphf php8.3-readline php8.3-redis php8.3-rrd \
    php8.3-smbclient php8.3-snmp php8.3-soap php8.3-solr php8.3-sqlite3 php8.3-ssh2 php8.3-sybase \
    php8.3-tideways php8.3-tidy \
    php8.3-uopz php8.3-uploadprogress php8.3-uuid \
    php8.3-xdebug php8.3-xml php8.3-xmlrpc php8.3-xsl \
    php8.3-yac php8.3-yaml \
    php8.3-zip php8.3-zmq \
    php-bacon-qr-code php-brick-math php-brick-varexporter \
    php-cache-integration-tests php-cache-tag-interop php-cas php-christianriesen-base32 php-christianriesen-otp \
    php-code-lts-u2f-php-server php-codecoverage php-codeigniter-framework php-composer-class-map-generator \
    php-email-validator php-embed php-facedetect-all-dev php-google-recaptcha php-jshrink php-json-schema \
    php-laravel-serializable-closure phpunit-cli-parser phpunit-code-unit pkg-php-tools \
    wordpress-shibboleth wordpress-xrds-simple \
    php8.3-mysqli php8.3-tokenizer && \
    mkdir -p /run/php/ && chown -Rf www-data.www-data /run/php && \
    #php8.3-oci8 php-sysvshm php8.3-gmagick php-symfony
    # install composer
    curl -sS https://getcomposer.org/installer | php && \
    mv composer.phar /usr/local/bin/composer && \
    printf "\nPATH=\"~/.composer/vendor/bin:\$PATH\"\n" | tee -a ~/.bashrc && \
    # set the locale \
    echo "LC_ALL=en_US.UTF-8" >> /etc/default/locale  && \
    locale-gen en_US.UTF-8  && \
    ln -sf /usr/share/zoneinfo/UTC /etc/localtime

# setup bash \
COPY .bash_aliases /root

# configur nginx
COPY homestead /etc/nginx/sites-available/
RUN rm -rf /etc/nginx/sites-available/default \
    && rm -rf /etc/nginx/sites-enabled/default \
    && ln -fs "/etc/nginx/sites-available/homestead" "/etc/nginx/sites-enabled/homestead" \
    && sed -i -e"s/keepalive_timeout\s*65/keepalive_timeout 2/" /etc/nginx/nginx.conf \
    && sed -i -e"s/keepalive_timeout 2/keepalive_timeout 2;\n\t client_max_body_size 100m/" /etc/nginx/nginx.conf \
    && echo "daemon off;" >> /etc/nginx/nginx.conf \
    && chown -Rf www-data:www-data /var/www/html/ \
    && sed -i -e"s/worker_processes 1/worker_processes 5/" /etc/nginx/nginx.conf
VOLUME ["/var/www/html/app"]
VOLUME ["/var/cache/nginx"]
VOLUME ["/var/log/nginx"]

# configur php
COPY fastcgi_params /etc/nginx/
RUN sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/8.3/cli/php.ini \
    && sed -i "s/display_errors = .*/display_errors = On/" /etc/php/8.3/cli/php.ini \
    && sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/php/8.3/cli/php.ini \
    && sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/8.3/fpm/php.ini \
    && sed -i "s/display_errors = .*/display_errors = On/" /etc/php/8.3/fpm/php.ini \
    && sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php/8.3/fpm/php.ini \
    && sed -i "s/upload_max_filesize = .*/upload_max_filesize = 100M/" /etc/php/8.3/fpm/php.ini \
    && sed -i "s/post_max_size = .*/post_max_size = 100M/" /etc/php/8.3/fpm/php.ini \
    && sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/php/8.3/fpm/php.ini \
    && sed -i "/extension=mongodb.so/d" /etc/php/8.3/cli/php.ini \
    && echo "extension=mongodb.so" >> /etc/php/8.3/cli/php.ini \
    && sed -i "/extension=mongodb.so/d" /etc/php/8.3/fpm/php.ini \
    && echo "extension=mongodb.so" >> /etc/php/8.3/fpm/php.ini \
    && sed -i "/extension=pgsql.so/d" /etc/php/8.3/cli/php.ini \
    && echo "extension=pgsql.so" >> /etc/php/8.3/cli/php.ini \
    && sed -i "/extension=pgsql.so/d" /etc/php/8.3/fpm/php.ini \
    && echo "extension=pgsql.so" >> /etc/php/8.3/fpm/php.ini \
    && sed -i "/extension=sqlite3.so/d" /etc/php/8.3/cli/php.ini \
    && echo "extension=sqlite3.so" >> /etc/php/8.3/cli/php.ini \
    && sed -i "/extension=sqlite3.so/d" /etc/php/8.3/fpm/php.ini \
    && echo "extension=sqlite3.so" >> /etc/php/8.3/fpm/php.ini \
    && sed -i "/extension=xdebug.so/d" /etc/php/8.3/cli/php.ini \
    && echo "extension=xdebug.so" >> /etc/php/8.3/cli/php.ini \
    && sed -i "/extension=xdebug.so/d" /etc/php/8.3/fpm/php.ini \
    && echo "extension=xdebug.so" >> /etc/php/8.3/fpm/php.ini \
    && sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php/8.3/fpm/php-fpm.conf \
    && sed -i -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" /etc/php/8.3/fpm/pool.d/www.conf \
    && sed -i -e "s/pm.max_children = 5/pm.max_children = 9/g" /etc/php/8.3/fpm/pool.d/www.conf \
    && sed -i -e "s/pm.start_servers = 2/pm.start_servers = 3/g" /etc/php/8.3/fpm/pool.d/www.conf \
    && sed -i -e "s/pm.min_spare_servers = 1/pm.min_spare_servers = 2/g" /etc/php/8.3/fpm/pool.d/www.conf \
    && sed -i -e "s/pm.max_spare_servers = 3/pm.max_spare_servers = 4/g" /etc/php/8.3/fpm/pool.d/www.conf \
    && sed -i -e "s/pm.max_requests = 500/pm.max_requests = 200/g" /etc/php/8.3/fpm/pool.d/www.conf \
    && sed -i -e "s/;listen.mode = 0660/listen.mode = 0750/g" /etc/php/8.3/fpm/pool.d/www.conf \
    && find /etc/php/8.3/cli/conf.d/ -name "*.ini" -exec sed -i -re 's/^(\s*)#(.*)/\1;\2/g' {} \; \
    # SSH server
    && mkdir -p /var/run/sshd \
    # Allow root login via password
    && sed -ri 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config && \
    # mysql configur
    echo mysql-server mysql-server/root_password password $DB_PASS | debconf-set-selections; \
    echo mysql-server mysql-server/root_password_again password $DB_PASS | debconf-set-selections; \
    echo "[mysqld]" >> /etc/mysql/my.cnf && \
    echo "default_password_lifetime = 0" >> /etc/mysql/my.cnf && \
    sed -i '/^bind-address/s/bind-address.*=.*/bind-address = 0.0.0.0/' /etc/mysql/my.cnf \
    && sed -i '/^bind-address/s/bind-address.*=.*/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf \
    && git clone https://github.com/mysqludf/lib_mysqludf_sys \
    #&& sed -i '/^LIBDIR/s/LIBDIR.*=.*/LIBDIR=/usr/lib/mysql/plugin' /lib_mysqludf_sys/Makefile \
    #&& lib_mysqludf_sys/install.sh \
    && find /var/lib/mysql -exec touch {} \; \
    && service mysql start \
    && sleep 10s \
    && echo "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '12345678'; \
    GRANT ALL ON *.* TO root@localhost; \
    CREATE USER 'homestead'@'%' IDENTIFIED BY 'secret'; \
    GRANT ALL ON *.* TO 'homestead'@'%'; \
    FLUSH PRIVILEGES; \
    CREATE DATABASE homestead;" | mysql

VOLUME ["/var/lib/mysql"]

#install laravel installer
RUN composer global require "laravel/installer"

# install gulp
#RUN /usr/bin/npm install -g gulp

# install bower
#RUN /usr/bin/npm install -g bower

# install blackfire
#RUN apt-get install -y blackfire-agent blackfire-php

# install supervisor
RUN mkdir -p /var/log/supervisor
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

VOLUME ["/var/log/supervisor"]

# clean up our mess
RUN apt-get remove --purge -y software-properties-common \
    && apt-get autoremove -y \
    && apt-get clean \
    && apt-get autoclean \
    && echo -n > /var/lib/apt/extended_states \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /usr/share/man/?? \
    && rm -rf /usr/share/man/??_*

# expose ports
EXPOSE 22
EXPOSE 80
EXPOSE 443
EXPOSE 3306
EXPOSE 6379

# set container entrypoints
ENTRYPOINT ["/bin/bash","-c"]
CMD ["/usr/bin/supervisord"]
