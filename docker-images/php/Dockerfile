ARG image

FROM $image

ARG image

SHELL ["/bin/bash", "-c"]

RUN docker-php-ext-install mysqli pdo_mysql pcntl

RUN if [[ "$image" == *"5.4"* ]]; then docker-php-ext-install mbstring; fi

RUN if [[ "$image" == *"7.2"* ]] || [[ "$image" == *"7.3"* ]] || [[ "$image" == *"7.4"* ]] ; then \
      pecl install channel://pecl.php.net/runkit7-4.0.0a2 && \
      echo "extension=runkit7.so" >> $PHP_INI_DIR/php.ini && \
      echo "runkit.internal_override = 1" >> $PHP_INI_DIR/php.ini; \
    fi

ADD entrypoint.sh /
