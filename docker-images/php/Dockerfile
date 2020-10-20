ARG image

FROM $image

ARG image

SHELL ["/bin/bash", "-c"]

RUN docker-php-ext-install mysqli pdo_mysql pcntl

RUN if [[ "$image" == *"5.4"* ]]; then docker-php-ext-install mbstring; fi

ADD entrypoint.sh /
