# Use TYPO3 v13 base image based on Apache2
# https://hub.docker.com/r/csidirop/typo3-v13/
# https://github.com/csidirop/typo3-docker/tree/typo3-v13.x
FROM csidirop/typo3-v13:latest
LABEL authors='Christos Sidiropoulos <Christos.Sidiropoulos@uni-mannheim.de>'

EXPOSE 80
ARG PHP_MEMORY_LIMIT

# This Dockerfile installs TYPO3 v13 with the kitodo/presentation extension
# based on this guide: https://github.com/UB-Mannheim/kitodo-presentation/wiki

# Update and install packages:
RUN apt-get update \
  && apt-get -y upgrade \
  && apt-get -y install -y --no-install-recommends \
    jq \
    gettext

# Copy startup script and data folder into the container:
COPY docker-entrypoint.sh docker-entrypoint-aux.sh /
ADD data/ /data

# Cleanup and last steps:
RUN apt-get purge -y \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists \
  # Fix wrong line endings in the startup script and just to be save in data files:
  && sed -i.bak 's/\r$//' /docker-entrypoint.sh /docker-entrypoint-aux.sh /data/*.* /data/scripts/* \
  # Ensure the startup script stays executable regardless of host file permissions:
  && chmod +x /docker-entrypoint.sh \
  # Set PHP memory limit:
  && sed -i "s/memory_limit = .*/memory_limit = ${PHP_MEMORY_LIMIT}/" /usr/local/etc/php/php.ini

# Run startup script & start apache2 (https://github.com/docker-library/php/blob/master/7.4/bullseye/apache/apache2-foreground)
CMD /docker-entrypoint.sh & apache2-foreground
