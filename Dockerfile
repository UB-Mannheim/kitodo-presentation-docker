# Install PHP 7.4 with Apache2 on Debian 11 bullseye:
FROM php:7.4-apache

LABEL authors='Christos Sidiropoulos <Christos.Sidiropoulos@uni-mannheim.de>'

EXPOSE 80

# This Dockerfile aimes to install a working typo3 instance with the kitodo/presentation extension
# based on this guide: https://github.com/UB-Mannheim/kitodo-presentation/wiki

# Upgrade system & install MariaDB (see https://mariadb.org/download/?t=repo-config&d=Debian+11+%22Bullseye%22&v=10.8):
RUN apt-get update \
  && apt-get -y upgrade \
  && apt-get install -y --no-install-recommends apt-transport-https curl \
  && curl -o /etc/apt/trusted.gpg.d/mariadb_release_signing_key.asc 'https://mariadb.org/mariadb_release_signing_key.asc' \
  && sh -c "echo 'deb https://mirror1.hs-esslingen.de/pub/Mirrors/mariadb/repo/10.8/debian bullseye main' >>/etc/apt/sources.list" \
  && apt-get update \
  && apt-get install -y --no-install-recommends mariadb-server 

#For baseimages other than php:7.4-apache:
#RUN apt-get install -y apache2 

# Workaround for "E: Package 'php-XXX' has no installation candidate" from https://hub.docker.com/_/php/ :
RUN rm /etc/apt/preferences.d/no-debian-php

# Install further php dependencies & composer & image processing setup:
RUN apt-get install -y --no-install-recommends \
  libapache2-mod-php \
  php-curl \
  php-gd \
  php-intl \
  php-mysql \
  php-xml \
  php-zip \
  composer \
  ghostscript \
  graphicsmagick \
  graphicsmagick-imagemagick-compat

# Start and setup MariaDB:
RUN service mariadb start \
  && mysqladmin create typo3 \
  && mysql -e "GRANT ALL ON typo3.* TO typo3@localhost IDENTIFIED BY 'password';" \
  && mysql -e "FLUSH PRIVILEGES;"

# Install and setup Typo3 & fix Typo3 warnings/problems:
WORKDIR /var/www/
RUN composer create-project typo3/cms-base-distribution:^9 typo3 \
  && touch typo3/public/FIRST_INSTALL \
  && chown -R www-data: typo3 \
  && cd html \
  && ln -s ../typo3/public/* . \
  && a2enmod php7.4 \
  && echo '<Directory /var/www/html>\n  AllowOverride All\n</Directory>' >> /etc/apache2/sites-available/typo3.conf \
  && a2ensite typo3 \
  && echo "fixing Low PHP script execution time & PHP max_input_vars very low:" \
  && echo ';Settings for Typo3: \nmax_execution_time=240 \nmax_input_vars=1500' >> /etc/php/7.4/mods-available/typo3.ini \
  && echo 'xdebug.max_nesting_level = 500' >> /etc/php/7.4/apache2/conf.d/20-xdebug.ini \
  && phpenmod typo3 \
  && service apache2 restart

RUN rm -rf /var/lib/apt/lists/*