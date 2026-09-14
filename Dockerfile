# Use TYPO3 v13 base image based on Apache2
# https://hub.docker.com/r/csidirop/typo3-v13/
# https://github.com/csidirop/typo3-docker/tree/typo3-v13.x
FROM csidirop/typo3-v13:latest
LABEL authors='Christos Sidiropoulos <Christos.Sidiropoulos@uni-mannheim.de>'

EXPOSE 80
# Set PHP memory limit (default: 512M) fallback:
ARG PHP_MEMORY_LIMIT=512M

# This Dockerfile installs TYPO3 v13 with the kitodo/presentation extension
# based on this guide: https://github.com/UB-Mannheim/kitodo-presentation/wiki

# Install envsubst, which is used by the startup script:
RUN apt-get update \
  && apt-get install -y --no-install-recommends gettext-base \
  && rm -rf /var/lib/apt/lists/*

# Copy startup script and data folder into the container:
COPY --chmod=0755 docker-entrypoint.sh docker-entrypoint-aux.sh /
COPY data/ /data/

# Set PHP memory limit:
RUN sed -i "s/memory_limit = .*/memory_limit = ${PHP_MEMORY_LIMIT}/" /usr/local/etc/php/php.ini

# Run setup synchronously. The script starts Apache as the final PID 1 process.
CMD ["/docker-entrypoint.sh"]
