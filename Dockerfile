# Use local typo3 v9 base image based on Apache2 on Debian 11 bullseye
# https://github.com/csidirop/typo3-docker/tree/typo3-v9.x
FROM csidirop/typo3-v9:9.5

LABEL authors='Christos Sidiropoulos <Christos.Sidiropoulos@uni-mannheim.de>'

ENV DB_ADDR=localhost
ENV DB_PORT=3306

EXPOSE 80

# This Dockerfile aimes to install a working typo3 v10 instance with the kitodo/presentation extension
# based on this guide: https://github.com/UB-Mannheim/kitodo-presentation/wiki

# Update:
RUN apt-get update \
  && apt-get -y upgrade \
  && apt-get -y install -y --no-install-recommends \
    apt-transport-https \
    lsb-release \
    wget \
    jq \
    gettext \
  && echo "deb https://notesalexp.org/tesseract-ocr5/$(lsb_release -cs)/ $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/notesalexp.list > /dev/null\
  && apt-get update -oAcquire::AllowInsecureRepositories=true \
  && apt-get install -y --allow-unauthenticated notesalexp-keyring -oAcquire::AllowInsecureRepositories=true\
  && apt-get update \
  && apt-get install -y tesseract-ocr \
  && cd /usr/share/tesseract-ocr/5/tessdata/ \
  && wget https://ub-backup.bib.uni-mannheim.de/~stweil/tesstrain/frak2021/tessdata_fast/frak2021_1.069.traineddata

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
RUN sed -i.bak 's/\r$//' /docker-entrypoint.sh  /data/*
# Run startup script & start apache2 (https://github.com/docker-library/php/blob/master/7.4/bullseye/apache/apache2-foreground)
CMD /docker-entrypoint.sh & apache2-foreground
