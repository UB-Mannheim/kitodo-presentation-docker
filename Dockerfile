# Use local typo3 v9 base image based on Apache2 on Debian 11 bullseye
# https://github.com/csidirop/typo3-docker/tree/typo3-v9.x
FROM csidirop/typo3-v9:9.5

LABEL authors='Christos Sidiropoulos <Christos.Sidiropoulos@uni-mannheim.de>'

EXPOSE 80

# This Dockerfile aimes to install a working typo3 v9 instance with the kitodo/presentation extension
# based on this guide: https://github.com/UB-Mannheim/kitodo-presentation/wiki

# Setup Typo3 with typo3console (https://docs.typo3.org/p/helhum/typo3-console/main/en-us/CommandReference/InstallSetup.html):
WORKDIR /var/www/typo3/
RUN docker-php-ext-install -j$(nproc) mysqli
RUN service mariadb start \
  && vendor/bin/typo3cms install:setup \ 
    --use-existing-database \
    --database-driver='mysqli' \
    --database-user-name='typo3' \
    --database-user-password='password' \
    --database-host-name='127.0.0.1' \
    --database-port=3306 \
    --database-name='typo3' \
    --admin-user-name='test' \
    --admin-password='test1234' \
    --site-setup-type=no \
    --site-name presentation \
    --web-server-config=apache

# Install Kitodo.Presentation:
RUN service mariadb start \ 
 && composer config platform.php 7.4 \
 && composer require kitodo/presentation:^3.3 \
 && vendor/bin/typo3 extensionmanager:extension:install dlf \
 && chown -R www-data:www-data .

# Define datavolumes:
#VOLUME /var/www/html/fileadmin
#VOLUME /var/www/html/typo3conf
#VOLUME /var/www/html/typo3temp