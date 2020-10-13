FROM php:7.4-cli

# Essentials
RUN apt-get update
RUN apt-get upgrade -y
RUN apt-get install -y software-properties-common gnupg2 git nano zip git wget curl python3-pip gettext

# GitHub CLI
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-key C99B11DEB97541F0
RUN apt-add-repository https://cli.github.com/packages
RUN apt-get update
RUN apt-get install gh

# Node
RUN curl -sL https://deb.nodesource.com/setup_12.x | bash -
RUN apt-get install -y nodejs build-essential

# Grunt and Bower
RUN npm install -g grunt-cli bower

# Transifex
RUN pip3 install transifex-client

WORKDIR /app

ADD run.sh /

ENTRYPOINT ["/bin/bash", "-c", "/run.sh \"$@\"", "--"]

