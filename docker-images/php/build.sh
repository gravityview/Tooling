#!/bin/bash
set -e

PHP_VERSIONS=(5.4 5.5 5.6 7.0 7.1 7.2 7.3 7.4)

build() {
  for VERSION in ${PHP_VERSIONS[*]}; do
    docker-compose build --force-rm php$VERSION
  done
}

tag() {
  for VERSION in ${PHP_VERSIONS[*]}; do
    docker tag $(docker images php_php$VERSION -q) gravityview/php:$VERSION
  done
}

push() {
  for VERSION in ${PHP_VERSIONS[*]}; do
    docker push gravityview/php:$VERSION
  done
}

$1
