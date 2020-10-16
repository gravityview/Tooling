FROM php:7.4-cli

# Essentials
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y software-properties-common gnupg2 git nano libzip-dev libpng-dev zip git wget curl python3-pip gettext ruby sass && \
    docker-php-ext-install zip gd

# GitHub CLI
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-key C99B11DEB97541F0 && \
    apt-add-repository https://cli.github.com/packages && \
    apt-get update && \
    apt-get install gh

# Node
RUN curl -sL https://deb.nodesource.com/setup_12.x | bash - && \
    apt-get install -y nodejs build-essential

# Grunt and Bower
RUN npm install -g grunt-cli bower

# Yarn
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
    apt-get update && \
    apt-get install yarn

# Composer
RUN cd ~ && curl -sS https://getcomposer.org/installer -o composer-setup.php && \
    php composer-setup.php --install-dir=/usr/local/bin --filename=composer

# Transifex
RUN pip3 install transifex-client

WORKDIR /app

ADD run.sh /

ENTRYPOINT ["/bin/bash", "-c", "/run.sh \"$@\"", "--"]

