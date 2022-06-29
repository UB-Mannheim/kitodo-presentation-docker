# Use local typo3 v10 base image based on Apache2 on Debian 11 bullseye
# https://github.com/csidirop/typo3-docker/tree/typo3-v10.x
FROM csidirop/typo3-v10:10.4-compose

LABEL authors='Christos Sidiropoulos <Christos.Sidiropoulos@uni-mannheim.de>'

ENV DB_ADDR=localhost
ENV DB_PORT=3306

EXPOSE 80

# This Dockerfile aimes to install a working typo3 v10 instance with the kitodo/presentation extension
# based on this guide: https://github.com/UB-Mannheim/kitodo-presentation/wiki

# Define datavolumes:
#VOLUME /var/www/html/fileadmin
#VOLUME /var/www/html/typo3conf
#VOLUME /var/www/html/typo3temp

# Copy startup script into the container:
COPY docker-entrypoint.sh /
# Fix wrong line endings in the startup script:
RUN sed -i.bak 's/\r$//' /docker-entrypoint.sh
# Run startup script & start apache2 (https://github.com/docker-library/php/blob/master/7.4/bullseye/apache/apache2-foreground)
CMD /docker-entrypoint.sh & apache2-foreground 