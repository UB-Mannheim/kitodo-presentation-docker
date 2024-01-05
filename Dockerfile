# Use TYPO3 v10 base image based on Apache2 on Debian 11 bullseye
# https://hub.docker.com/r/csidirop/typo3-v10/
# https://github.com/csidirop/typo3-docker/tree/typo3-v10.x
FROM csidirop/typo3-v10:10.4-230202

LABEL authors='Christos Sidiropoulos <Christos.Sidiropoulos@uni-mannheim.de>'

EXPOSE 80

# This Dockerfile aims to install a working TYPO3 v10 instance with the kitodo/presentation extension
# based on this guide: https://github.com/UB-Mannheim/kitodo-presentation/wiki

# Update and install packages:
RUN apt-get update \
  && apt-get -y upgrade \
  && apt-get -y install -y --no-install-recommends \
    lsb-release \
    wget \
    jq \
    gettext \
    python3 \
    python3-pip \
  && pip install virtualenv

# Install OCR Engines: Tesseract v5 (https://notesalexp.org/tesseract-ocr/#tesseract_5.x) and Kraken (https://github.com/mittagessen/kraken)
SHELL ["/bin/bash", "-c"]
RUN \
  # install kraken:
  virtualenv -p python3 /opt/kraken_venv \
  && . /opt/kraken_venv/bin/activate \
    && pip install kraken \
    && pip install kraken[pdf] \
    && deactivate \
  # get default model (en_best):
  && /opt/kraken_venv/bin/kraken get 10.5281/zenodo.2577813 \
  # install tesseract:
  && echo "deb https://notesalexp.org/tesseract-ocr5/$(lsb_release -cs)/ $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/notesalexp.list > /dev/null \
  && apt-get update -oAcquire::AllowInsecureRepositories=true \
  && apt-get install -y --allow-unauthenticated notesalexp-keyring -oAcquire::AllowInsecureRepositories=true \
  && apt-get update \
  && apt-get install -y tesseract-ocr

# Install tools for mets.xml manipulation:
RUN \
  # install OCR-D for cli usage:
  virtualenv -p python3 /opt/ocrd_venv \
  && . /opt/ocrd_venv/bin/activate \
  && pip install -U pip wheel ocrd \ 
  # xml utils:
  && apt-get install -y xmlstarlet libxml2-utils

# Update $PATH:
ENV PATH="$PATH:/opt/kraken_venv/bin/:/opt/ocrd_venv/bin/"

# Copy startup script and data folder into the container:
COPY docker-entrypoint.sh docker-entrypoint-aux.sh /
ADD data/ /data

ARG PHP_MEMORY_LIMIT
ENV PHP_MEMORY_LIMIT $PHP_MEMORY_LIMIT

# Cleanup and last steps:
RUN apt-get purge -y \
        lsb-release \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists \
  # Fix wrong line endings in the startup script and just to be save in data files:
  && sed -i.bak 's/\r$//' /docker-entrypoint.sh /docker-entrypoint-aux.sh /data/*.* /data/scripts/* \
  # Set PHP memory limit:
  && sed -i "s/memory_limit = .*/memory_limit = ${PHP_MEMORY_LIMIT}/" /etc/php/7.4/apache2/php.ini

# Run startup script & start apache2 (https://github.com/docker-library/php/blob/master/7.4/bullseye/apache/apache2-foreground)
CMD /docker-entrypoint.sh & apache2-foreground
