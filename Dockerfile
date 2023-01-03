# Use TYPO3 v9 base image based on Apache2 on Debian 11 bullseye
# https://hub.docker.com/r/csidirop/typo3-v9/
# https://github.com/csidirop/typo3-docker/tree/typo3-v9.x
FROM csidirop/typo3-v9:9.5-221101

LABEL authors='Christos Sidiropoulos <Christos.Sidiropoulos@uni-mannheim.de>'

ENV DB_ADDR=localhost
ENV DB_PORT=3306

EXPOSE 80

# This Dockerfile aimes to install a working TYPO3 v9 instance with the kitodo/presentation extension
# based on this guide: https://github.com/UB-Mannheim/kitodo-presentation/wiki

# Update and install packages:
RUN apt-get update \
  && apt-get -y upgrade \
  && apt-get -y install -y --no-install-recommends \
    apt-transport-https \
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
  && source /opt/kraken_venv/bin/activate \
    && pip install kraken \
    && pip install kraken[pdf] \
    && python3 -m pip install numpy==1.23.5 \
    && deactivate \
# && export PATH=$PATH:/opt/kraken_venv/bin/ \
  && /opt/kraken_venv/bin/kraken get 10.5281/zenodo.2577813 \
  && /opt/kraken_venv/bin/kraken get 10.5281/zenodo.6891852 \
  && mkdir /opt/kraken_models/ \
  && wget https://ub-backup.bib.uni-mannheim.de/~stweil/tesstrain/kraken/digitue-gt/digitue_best.mlmodel -P /opt/kraken_models/ \
  && wget https://ub-backup.bib.uni-mannheim.de/~stweil/tesstrain/kraken/german_handwriting/german_handwriting_best.mlmodel -P /opt/kraken_models/ \
  # install tesseract:
  && echo "deb https://notesalexp.org/tesseract-ocr5/$(lsb_release -cs)/ $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/notesalexp.list > /dev/null \
  && apt-get update -oAcquire::AllowInsecureRepositories=true \
  && apt-get install -y --allow-unauthenticated notesalexp-keyring -oAcquire::AllowInsecureRepositories=true \
  && apt-get update \
  && apt-get install -y tesseract-ocr \
  # Get language data from UB Mannheim:
  && wget https://ub-backup.bib.uni-mannheim.de/~stweil/tesstrain/frak2021/tessdata_fast/frak2021_1.069.traineddata -O /usr/share/tesseract-ocr/5/tessdata/frak2021_1.069.traineddata

# Cleanup:
RUN apt-get purge -y \
        apt-transport-https \
        lsb-release \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy startup script and data folder into the container:
COPY docker-entrypoint.sh /
ADD data/ /data
# Fix wrong line endings in the startup script and just to be save in data files:
RUN sed -i.bak 's/\r$//' /docker-entrypoint.sh /data/*.* /data/scripts/*
# Run startup script & start apache2 (https://github.com/docker-library/php/blob/master/7.4/bullseye/apache/apache2-foreground)
CMD /docker-entrypoint.sh & apache2-foreground
