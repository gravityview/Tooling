#!/usr/bin/env bash

# read environment variables from .env file if it exists
[ -f '.env' ] && source <(grep -v '^#' .env | sed -E 's|^(.+)=(.*)$|: ${\1=\2}; export \1|g')

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
PLUGIN_DIR=${PLUGIN_DIR:-./}
GF_PLUGIN_DIR=${GF_PLUGIN_DIR:-./gravityforms}
GV_PLUGIN_DIR=${GV_PLUGIN_DIR:-./gravityview}
WP_51_TESTS_DIR=${WP_51_TESTS_DIR:-./wordpress-51-tests-lib}
WP_LATEST_TESTS_DIR=${WP_LATEST_TESTS_DIR:-./wordpress-latest-tests-lib}
PHPUNIT_DIR=${PHPUNIT_DIR:-./phpunit}
GH_AUTH_TOKEN=${GH_AUTH_TOKEN:-}
PHP_VERSIONS=(5.4 5.5 5.6 7.0 7.1 7.2 7.3 7.4)
FORCE_DOWNLOAD=false

DEPENDENCIES=(git unzip wget jq docker-compose)

(cat <<-END

         ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
         ┃    ____                 _ _       __     ___                 ┃▒
         ┃   / ___|_ __ __ ___   _(_) |_ _   \ \   / (_) _____      __  ┃▒
         ┃  | |  _| '__/ _\ \ \ / / | __| | | \ \ / /| |/ _ \ \ /\ / /  ┃▒
         ┃  | |_| | | | (_| |\ V /| | |_| |_| |\ V / | |  __/\ V  V /   ┃▒
         ┃   \____|_|  \__,_| \_/ |_|\__|\__, | \_/  |_|\___| \_/\_/    ┃▒
         ┃                               |___/                          ┃▒
         ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ Docker Unit Tests 1.0 ━┛▒
          ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒

END
)

######################### Helpers
_abort() {
	local _ret="${2:-1}"
	echo "$1" >&2
	exit "${_ret}"
}

_do_preflight_check() {
  for dependency in ${DEPENDENCIES[*]}
  do
    if ! [ -x "$(command -v ${dependency})" ]; then
      _abort "\"$dependency\" system command must be installed to continue"
    fi
  done
}

_run_docker_compose() {
  if [ ! -f $WP_51_TESTS_DIR/wp-tests-config.php ] || [ ! -f $WP_LATEST_TESTS_DIR/wp-tests-config.php ]; then
    _abort "Run \"configure_test_suits\" before running tests"
  fi

  local PHPUNIT_CONFIG="$PLUGIN_DIR/phpunit.xml"
  local PHPUNIT_CONFIG_ALT="$PLUGIN_DIR/phpunit.xml.dist"

  if [ ! -f PHPUNIT_CONFIG ] && [ -f $PHPUNIT_CONFIG_ALT ]; then
    PHPUNIT_CONFIG=$PHPUNIT_CONFIG_ALT
  elif [ ! -f $PHPUNIT_CONFIG ]; then
    _abort "\"$PHPUNIT_CONFIG\" is not found"
  fi

  ENV="-v $(grep -v '^#' .env | awk '{print}' ORS=' -e ')"

  (export \
     PLUGIN_DIR=$PLUGIN_DIR \
     GF_PLUGIN_DIR=$GF_PLUGIN_DIR \
     PHPUNIT_DIR=$PHPUNIT_DIR \
     WP_51_TESTS_DIR=$WP_51_TESTS_DIR \
     WP_LATEST_TESTS_DIR=$WP_LATEST_TESTS_DIR ;\
   docker-compose -f $SCRIPT_DIR/docker-compose.yml run $ENV --rm $1 -c $PHPUNIT_CONFIG $2\
  ) || _abort "Docker exited with an error"
}

######################### Available commands
configure_test_suits() {
  if [ ! -f $WP_51_TESTS_DIR/wp-tests-config-sample.php ] || [ ! -f $WP_LATEST_TESTS_DIR/wp-tests-config-sample.php ]; then
    _abort "Run \"download_test_suits\" before configuring them"
  fi

 	# portable in-place argument for both GNU sed and Mac OSX sed (taken from WP's script)
	if [[ $(uname -s) == 'Darwin' ]]; then
		local ioption='-i.bak'
	else
		local ioption='-i'
	fi

  TEST_SUITS=($WP_51_TESTS_DIR $WP_LATEST_TESTS_DIR)

  for test_suites in ${TEST_SUITS[*]}
  do
    cp $test_suites/wp-tests-config-sample.php $test_suites/wp-tests-config.php

    sed $ioption "s/'youremptytestdbnamehere'/getenv('MYSQL_DATABASE')/" "$test_suites"/wp-tests-config.php
    sed $ioption "s/'yourusernamehere'/getenv('MYSQL_USER')/" "$test_suites"/wp-tests-config.php
	  sed $ioption "s/'yourpasswordhere'/getenv('MYSQL_PASSWORD')/" "$test_suites"/wp-tests-config.php
	  sed $ioption "s/'localhost'/getenv('MYSQL_HOST')/" "$test_suites"/wp-tests-config.php
  done

	echo "SUCCESS: test suits configured"
}

download_test_suits() {
  local WP_51_HASH=$(wget -O - -q https://api.github.com/repos/WordPress/wordpress-develop/tags | jq 'map( select( .name | startswith( "5.1" ) ) ) | first | .commit.sha' | tr -d '"')
  local WP_LATEST_HASH=$(wget -O - -q https://api.github.com/repos/WordPress/wordpress-develop/tags | jq '.[0].commit.sha' | tr -d '"')

  if [ -f $WP_51_TESTS_DIR/.cache_hash ] && [ "$WP_51_HASH" == "$(head -n 1 $WP_51_TESTS_DIR/.cache_hash )" ] && [ "$FORCE_DOWNLOAD" != true ]; then
    echo "WP 5.1 test suite has not changed; skipping..."
  else
    [ -d $WP_51_TESTS_DIR ] && rm -rf $WP_51_TESTS_DIR

    mkdir -p $WP_51_TESTS_DIR

    echo "Downloading WP 5.1 test suite..."

   	wget -O - -q https://api.github.com/repos/WordPress/wordpress-develop/tags |\
		  jq 'map( select( .name | startswith( "5.1" ) ) ) | first | .tarball_url' |\
		  tr -d '"' |\
		  xargs -n1 wget -O - -q |\
		  tar --strip-components=1 -zx -C $WP_51_TESTS_DIR

	  echo $WP_51_HASH > $WP_51_TESTS_DIR/.cache_hash
  fi

  if [ -f $WP_LATEST_TESTS_DIR/.cache_hash ] && [ "$WP_LATEST_HASH" == "$(head -n 1 $WP_LATEST_TESTS_DIR/.cache_hash )" ]; then
    echo "Latest WP test suite has not changed; skipping..."
  else
    [ -d $WP_LATEST_TESTS_DIR ] && rm -rf $WP_LATEST_TESTS_DIR

    mkdir -p $WP_LATEST_TESTS_DIR

    echo "Downloading latest WP test suite..."

  	wget -O - -q https://api.github.com/repos/WordPress/wordpress-develop/tags |\
	    jq '.[0].tarball_url' |\
	    tr -d '"' |\
	    xargs -n1 wget -O - -q |\
	    tar --strip-components=1 -zx -C $WP_LATEST_TESTS_DIR

	  echo $WP_LATEST_HASH > $WP_LATEST_TESTS_DIR/.cache_hash
  fi

	echo "SUCCESS: test suits downloaded"
}

download_phpunit() {
  if [ -f $PHPUNIT_DIR/phpunit4 ] && [ -f $PHPUNIT_DIR/phpunit5 ] && [ -f $PHPUNIT_DIR/phpunit6 ] && [ -f $PHPUNIT_DIR/phpunit7 ] && [ "$FORCE_DOWNLOAD" != true ]; then
    echo "PHPUnit has already been downloaded; skipping..."

    return
  fi

  [ -d $PHPUNIT_DIR ] || mkdir -p $PHPUNIT_DIR

  wget -O $PHPUNIT_DIR/phpunit4 https://phar.phpunit.de/phpunit-4.phar
  wget -O $PHPUNIT_DIR/phpunit5 https://phar.phpunit.de/phpunit-5.phar
  wget -O $PHPUNIT_DIR/phpunit6 https://phar.phpunit.de/phpunit-6.phar
  wget -O $PHPUNIT_DIR/phpunit7 https://phar.phpunit.de/phpunit-7.phar

  chmod +x $PHPUNIT_DIR/phpunit*

	echo "SUCCESS: PHPUnit downloaded"
}

download_gravityview() {
  if [ -z "${GH_AUTH_TOKEN}" ]; then
    _abort '"GH_AUTH_TOKEN" environment variable must be set to continue'
  fi

  local GV_LATEST_HASH=$(wget --header="Authorization: token $GH_AUTH_TOKEN" -O - -q https://api.github.com/repos/gravityview/gravityview/tags | jq '.[0].commit.sha' | tr -d '"')

  if [ -f $GV_PLUGIN_DIR/.cache_hash ] && [ "$GV_LATEST_HASH" == "$(head -n 1 $GV_PLUGIN_DIR/.cache_hash )" ] && [ "$FORCE_DOWNLOAD" != true ]; then
    echo "Latest GravityView has already been downloaded; skipping..."

    return
  fi

  [ -d $GV_PLUGIN_DIR ] && rm -rf $GV_PLUGIN_DIR

  mkdir -p $GV_PLUGIN_DIR

  if [[ $1 == 'clone' ]]; then
    echo "Cloning GravityView repo..."
    git clone https://github.com/gravityview/GravityView.git $GV_PLUGIN_DIR
  else
    wget --header="Authorization: token $GH_AUTH_TOKEN" -O - -q https://api.github.com/repos/gravityview/gravityview/tags |\
      jq ".[0].tarball_url" |\
      tr -d '"' |\
      xargs -n1 wget --header="Authorization: token $GH_AUTH_TOKEN" -O - -q |\
      tar --strip-components=1 -zx -C $GV_PLUGIN_DIR
  fi

  echo $GV_LATEST_HASH > $GV_PLUGIN_DIR/.cache_hash

	[[ $1 == 'clone' ]] && echo "SUCCESS: GravityView repo cloned" || echo "SUCCESS: GravityView downloaded"
}

download_gravity_forms() {
  if [ -z "${GH_AUTH_TOKEN}" ]; then
    _abort '"GH_AUTH_TOKEN" environment variable must be set to continue'
  fi

  local GF_LATEST_HASH=$(wget --header="Authorization: token $GH_AUTH_TOKEN" -O - -q https://api.github.com/repos/gravityforms/gravityforms/tags | jq '.[0].commit.sha' | tr -d '"')

  if [ -f $GF_PLUGIN_DIR/.cache_hash ] && [ "$GF_LATEST_HASH" == "$(head -n 1 $GF_PLUGIN_DIR/.cache_hash )" ] && [ "$FORCE_DOWNLOAD" != true ]; then
    echo "Latest Gravity Forms has already been downloaded; skipping..."

    return
  fi

  [ -d $GF_PLUGIN_DIR ] && rm -rf $GF_PLUGIN_DIR

  mkdir -p $GF_PLUGIN_DIR

  echo "Downloading latest Gravity Forms..."

  wget --header="Authorization: token $GH_AUTH_TOKEN" -O - -q https://api.github.com/repos/gravityforms/gravityforms/tags |\
    jq ".[0].tarball_url" |\
    tr -d '"' |\
    xargs -n1 wget --header="Authorization: token $GH_AUTH_TOKEN" -O - -q |\
    tar --strip-components=1 -zx -C $GF_PLUGIN_DIR

	echo $GF_LATEST_HASH > $GF_PLUGIN_DIR/.cache_hash

	echo "SUCCESS: Gravity Forms downloaded"
}

prepare_all() {
  download_phpunit
  download_gravity_forms
  download_test_suits
  configure_test_suits
}

test_54() {
  _run_docker_compose "php5.4 $PHPUNIT_DIR/phpunit4 --no-coverage $1"
}

test_55() {
  _run_docker_compose "php5.5 $PHPUNIT_DIR/phpunit4 --no-coverage $1"
}

test_56() {
  _run_docker_compose "php5.6 $PHPUNIT_DIR/phpunit5 --no-coverage $1"
}

test_70() {
  _run_docker_compose "php7.0 $PHPUNIT_DIR/phpunit6 --no-coverage $1"
}

test_71() {
  _run_docker_compose "php7.1 $PHPUNIT_DIR/phpunit7 --no-coverage $1"
}

test_72() {
  _run_docker_compose "php7.2 $PHPUNIT_DIR/phpunit7 --no-coverage $1"
}

test_73() {
  _run_docker_compose "php7.3 $PHPUNIT_DIR/phpunit7 --no-coverage $1"
}

test_74() {
  _run_docker_compose "php7.4 $PHPUNIT_DIR/phpunit7 --no-coverage $1"
}

test_all() {
  test_54 "$1"
  test_55 "$1"
  test_56 "$1"
  test_70 "$1"
  test_71 "$1"
  test_73 "$1"
  test_72 "$1"
  test_74 "$1"
}

######################### Runtime magic :)
set -e

if [ -z "$1" ]; then
  HELP=$(cat <<-END
To prepare a test environment:
    download_phpunit                 Download PHPUnit 4-7
    download_gravity_forms           Download latest Gravity Forms
    download_gravityview             Download latest GravityView (use "-o clone" to clone the repo instead of download latest release)
    download_test_suits              Download WordPress Develop 5.1 and latest version
    configure_test_suits             Update WP test config files

    prepare_all                      Run all test preparation actions

    (use --force-download to bypass caching of Gravity Forms and PHPUnit)

To run unit tests:
    test_54                          Test using PHP 5.4, WP 5.1 and PHPUnit 4
    test_55                          Test using PHP 5.5, WP 5.1 and PHPUnit 4
    test_56                          Test using PHP 5.6, latest WP and PHPUnit 5
    test_70                          Test using PHP 7.0, latest WP and PHPUnit 6
    test_71                          Test using PHP 7.1, latest WP and PHPUnit 7
    test_72                          Test using PHP 7.2, latest WP and PHPUnit 7
    test_73                          Test using PHP 7.3, latest WP and PHPUnit 7
    test_74                          Test using PHP 7.4, latest WP and PHPUnit 7

    test_all                         Run all tests

    (use -o to pass optional PHPUnit commands; e.g., test_72 -o "--filter GVFuture_Test::test_plugin_dir_and_url_and_relpath")

The following environment variables are used:

    WP_51_TESTS_DIR                  WP 5.1 test suit location (default: ./wordpress-51-tests-lib)
    WP_LATEST_TESTS_DIR              Latest WP test suit location (default: ./wordpress-latest-tests-lib)
    PHPUNIT_DIR                      PHPUnit executables location (default: ./phpunit)
    GF_PLUGIN_DIR                    Gravity Forms location (default: ./gravityforms)
    PLUGIN_DIR                       Location of the plugin that's being tested (default: ./)
    GH_AUTH_TOKEN                    GitHub auth token (required to download Gravity Forms)

Examples:
    ./docker-unit-tests.sh prepare_all test_all
    ./docker-unit-tests.sh test_all -o "--filter GVFuture_Test::test_plugin_dir_and_url_and_relpath"
    ./docker-unit-tests.sh --force-download download_gravity_forms

END
)
  _abort "$HELP"
else
  _do_preflight_check

  [[ "$*" =~ "--force-download" ]] && FORCE_DOWNLOAD=true

  while (( "$#" )); do
    case "$1" in
      -o)
        shift 2
        ;;
      *)
        if [[ "$1" =~ "--" ]]; then
          shift
        elif ! declare -f "$1" > /dev/null; then
          _abort "$1 option does not exist"
        fi

        if [ -n "$2" ] && [ $2 == "-o" ]; then
          "$1" "$3"
        else
          "$1"
        fi
        shift
        ;;
    esac
  done
fi
