FROM php:7.4-cli

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y git nano zip git wget curl python3-pip gettext

RUN curl -sL https://deb.nodesource.com/setup_12.x | bash -

RUN apt-get install -y nodejs build-essential

RUN npm install -g grunt-cli bower

RUN pip3 install transifex-client

WORKDIR /app
