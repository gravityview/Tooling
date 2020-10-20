#!/bin/bash
set -e

if [ "$USER" = "root" ]; then

    # set localtime
    ln -sf /usr/share/zoneinfo/$LOCALTIME /etc/localtime

    # secure path
    chmod a-rwx -R $PHP_INI_DIR/conf.d/
fi

#
# functions
function set_conf {
    echo ''>$2; IFSO=$IFS; IFS=$(echo -en "\n\b")
    for c in `printenv|grep $1`; do echo "`echo $c|cut -d "=" -f1|awk -F"$1" '{print $2}'` $3 `echo $c|cut -d "=" -f2`" >> $2; done;
    IFS=$IFSO
}

#
# PHP
echo "date.timezone = \"${LOCALTIME}\"" >> $PHP_INI_DIR/conf.d/00-default.ini
if [ "$PHP_php5enmod" != "" ]; then docker-php-ext-enable $PHP_php5enmod > /dev/null 2>&1; fi;
set_conf "PHP__" "$PHP_INI_DIR/conf.d/40-user.ini" "="

if [[ ! -z "$1" ]]; then
    eval "php $@"
else
    exec php -h
fi
