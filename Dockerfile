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

# Set root password
RUN echo 'root:root' | chpasswd

# upgrade the container
RUN apt-get update && apt-get upgrade -y

# install some prerequisites
RUN apt-get update && apt-get install -y --no-install-recommends apt-utils

RUN apt-get install -y software-properties-common curl \
    build-essential dos2unix gcc git libmcrypt4 libpcre3-dev python3-pip wget zip \
    unattended-upgrades whois vim debconf-utils libnotify-bin locales \
    cron libpng-dev unzip memcached make

# set the locale
RUN echo "LC_ALL=en_US.UTF-8" >> /etc/default/locale  && \
    locale-gen en_US.UTF-8  && \
    ln -sf /usr/share/zoneinfo/UTC /etc/localtime

# setup bash
COPY .bash_aliases /root

# install nginx
RUN apt-get install -y nginx openssh-server libssl-dev libcurl4-openssl-dev libxml2-dev libzip-dev
#RUN apt-get install -y --allow-downgrades --allow-remove-essential --allow-change-held-packages nginx
COPY homestead /etc/nginx/sites-available/
RUN rm -rf /etc/nginx/sites-available/default \
    && rm -rf /etc/nginx/sites-enabled/default \
    && ln -fs "/etc/nginx/sites-available/homestead" "/etc/nginx/sites-enabled/homestead" \
    && sed -i -e"s/keepalive_timeout\s*65/keepalive_timeout 2/" /etc/nginx/nginx.conf \
    && sed -i -e"s/keepalive_timeout 2/keepalive_timeout 2;\n\tclient_max_body_size 100m/" /etc/nginx/nginx.conf \
    && echo "daemon off;" >> /etc/nginx/nginx.conf

# Adjust permissions and worker processes
#RUN if ! id -u www-data | grep -q 1000; then \
    #usermod -u 1000 www-data; \
    #fi \
    #&& chown -Rf www-data:www-data /var/www/html/ \
    #&& sed -i -e"s/worker_processes 1/worker_processes 5/" /etc/nginx/nginx.conf
RUN chown -Rf www-data:www-data /var/www/html/ \
    && sed -i -e"s/worker_processes 1/worker_processes 5/" /etc/nginx/nginx.conf

VOLUME ["/var/www/html/app"]
VOLUME ["/var/cache/nginx"]
VOLUME ["/var/log/nginx"]

# install php
#RUN add-apt-repository ppa:ondrej/php && \
    #apt-get install -y php php-fpm php-mysql php-curl php-json php-cgi php-mbstring php-xmlrpc \
    #php-soap php-gd php-xml php-intl php-cli php-zip php-xdebug php-common php-imap php-readline \
    #php-bcmath php-imagick php-imagick php-ldap php-bz2 php-pgsql

RUN add-apt-repository ppa:ondrej/php && \
    apt-get update && \
    apt-get install -y php8.3 php8.3-fpm php8.3-mysql php8.3-curl php-json php8.3-cgi \
    php8.3-mbstring php8.3-xmlrpc php8.3-soap php8.3-gd php8.3-xml php8.3-intl php8.3-cli \
    php8.3-zip php8.3-xdebug php8.3-common php8.3-imap php8.3-readline php8.3-bcmath \
    php8.3-imagick php8.3-ldap php8.3-bz2 php8.3-pgsql php8.3-opcache php8.3-redis php8.3-sqlite3

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
    && sed -ri 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config


RUN mkdir -p /run/php/ && chown -Rf www-data.www-data /run/php

# install composer
RUN curl -sS https://getcomposer.org/installer | php && \
    mv composer.phar /usr/local/bin/composer && \
    printf "\nPATH=\"~/.composer/vendor/bin:\$PATH\"\n" | tee -a ~/.bashrc

# install sqlite
RUN apt-get install -y sqlite3 libsqlite3-dev \
    # install mysql
    echo mysql-server mysql-server/root_password password $DB_PASS | debconf-set-selections; \
    echo mysql-server mysql-server/root_password_again password $DB_PASS | debconf-set-selections; \
    apt-get install -y mysql-server default-libmysqlclient-dev && \
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


# install nodejs
RUN apt-get install -y nodejs

#install laravel installer
RUN composer global require "laravel/installer"

# install gulp
#RUN /usr/bin/npm install -g gulp

# install bower
#RUN /usr/bin/npm install -g bower

# install redis
RUN apt-get install -y redis-server

# install blackfire
#RUN apt-get install -y blackfire-agent blackfire-php

# install supervisor
RUN apt-get install -y supervisor && mkdir -p /var/log/supervisor
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
# copy supervisor config file to start openssh-server
#COPY openssh-server.conf /etc/supervisor/conf.d/openssh-server.conf



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