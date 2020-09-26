#!/usr/bin/env bash

# read environment variables from .env file if it exists
[ -f '.env' ] && source <(grep -v '^#' .env | sed -E 's|^(.+)=(.*)$|: ${\1=\2}; export \1|g')

CIRCLE_TOKEN=${CIRCLE_TOKEN:-}
CIRCLE_WORKFLOW_ID=${CIRCLE_WORKFLOW_ID:-}
CIRCLE_BUILD_NUM=${CIRCLE_BUILD_NUM:-}

GV_RELEASE_MANAGER_URL=${GV_RELEASE_MANAGER_URL:-}
GV_RELEASE_MANAGER_TOKEN=${GV_RELEASE_MANAGER_TOKEN:-}

DEPENDENCIES=(curl jq git docker-compose)

BANNER=$(cat <<-END

         ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
         ┃    ____                 _ _       __     ___                 ┃▒
         ┃   / ___|_ __ __ ___   _(_) |_ _   \ \   / (_) _____      __  ┃▒
         ┃  | |  _| '__/ _\ \ \ / / | __| | | \ \ / /| |/ _ \ \ /\ / /  ┃▒
         ┃  | |_| | | | (_| |\ V /| | |_| |_| |\ V / | |  __/\ V  V /   ┃▒
         ┃   \____|_|  \__,_| \_/ |_|\__|\__, | \_/  |_|\___| \_/\_/    ┃▒
         ┃                               |___/                          ┃▒
         ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ Build Tools 1.0 ━┛▒
          ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
END
)

######################### Helpers
_abort() {
	_ret="${2:-1}"
	echo "$1" >&2
	exit "${_ret}"
}

_do_preflight_check() {
  for dependency in ${DEPENDENCIES[*]}
  do
    if ! [ -x "$(command -v ${dependency})" ]; then
      _abort "ERROR: \"$dependency\" system command must be installed to continue"
    fi
  done
}

_run_docker() {
  (docker run --rm \
    --user $(id -u):$(id -g) \
    --volume /etc/passwd:/etc/passwd:ro \
    --volume /etc/group:/etc/group:ro \
    --volume $PWD:/app \
    --volume $HOME:$HOME \
    gravityview/build_environment $@
  ) || _abort "ERROR: Docker exited with an error"
}

_get_plugin_version() {
  [ -z "$1" ] || ! [ -s "$1" ] && _abort "ERROR: $1 plugin file not found"

  PLUGIN_VERSION=$(cat $1 | grep -m1 -Po '(?<=Version:).*' | tr -d "  ")

  [ -z "$PLUGIN_VERSION" ] && _abort "ERROR: plugin version could not be found inside $PWD/$1"

  eval "$2='$PLUGIN_VERSION'"
}

_get_plugin_name() {
  [ -z "$1" ] || ! [ -s "$1" ] && _abort "ERROR: $1 plugin file not found"

  PLUGIN_NAME=$(cat $1 | grep -m1 -Po '(?<=Name:).*')

  [ -z "$PLUGIN_NAME" ] && _abort "ERROR: plugin name could not be found inside $PWD/$1"

  eval "$2='$PLUGIN_NAME'"
}

######################### Available commands
php() {
  _run_docker php "$@"
}

grunt() {
  _run_docker grunt "$@"
}

npm() {
  _run_docker npm "$@"
}

plugin_version() {
  HELP=$(cat <<-END
${BANNER}

Required syntax: plugin_version -o plugin_file.php
END
)

  [ -z "$1" ] && _abort "$HELP"

  _get_plugin_version $1 PLUGIN_VERSION

  echo $PLUGIN_VERSION
}

plugin_name() {
  HELP=$(cat <<-END
${BANNER}

Required syntax: plugin_name -o plugin_file.php
END
)

  [ -z "$1" ] && _abort "$HELP"

  _get_plugin_name $1 PLUGIN_NAME

  echo $PLUGIN_NAME
}

package_build() {
  args=($1)

  HELP=$(cat <<-END
${BANNER}

Required syntax: package_build -o "archive_prefix plugin_file.php --include-hash"

    archive_prefix                     Archive prefix (e.g., "gravityview" will result in "gravityview-<version>.zip" archive)
    plugin_file                        Main plugin file (e.g., "gravityview.php")
    (optional) --include-hash          Commit hash will be included in the archive name
END
)

  [ -z "${args[0]}" ] || [ -z "${args[1]}" ] || ! [ -s ${args[1]} ] && _abort "$HELP"

  GH_COMMIT_HASH='' && [[ "$*" =~ "--include-hash" ]] && GH_COMMIT_HASH="-$(git log --pretty=format:'%h' -n 1)"

  _get_plugin_version "${args[1]}" PLUGIN_VERSION

  BUILD_ARCHIVE="${args[0]}-$PLUGIN_VERSION$GH_COMMIT_HASH.zip"

  git archive HEAD --format=zip --prefix=${args[0]}/ --output=$BUILD_ARCHIVE

  ! [ -s ${args[1]} ] && _abort "ERROR: $BUILD_ARCHIVE is empty"

  echo "SUCCESS: $BUILD_ARCHIVE was created"
}

announce_build() {
      HELP=$(cat <<-END
${BANNER}

Required syntax: announce_build -o plugin_file.php
Required environment variables: CIRCLE_TOKEN, CIRCLE_WORKFLOW_ID, CIRCLE_BUILD_NUM, GV_RELEASE_MANAGER_URL and GV_RELEASE_MANAGER_TOKEN
END
)
  [ -z "$1" ] && _abort "$HELP"

  REQUIRED_VARS=(CIRCLE_TOKEN CIRCLE_WORKFLOW_ID CIRCLE_BUILD_NUM GV_RELEASE_MANAGER_URL GV_RELEASE_MANAGER_TOKEN)

  for required_var in ${REQUIRED_VARS[*]}
  do
    [ -z "${!required_var}" ] && _abort "ERROR: $required_var environment variable is not set"
  done

  GH_COMMIT_TIMESTAMP=$(git log --pretty=format:'%at' -n 1)
  GH_COMMIT_HASH=$(git log --pretty=format:'%h' -n 1)
  GH_COMMIT_TAG=$(git tag --points-at HEAD)

  echo "Getting CI workflow info..."
  CIRCLE_WORKFLOW_INFO=$(curl -s -H "Accept: application/json" -H "Circle-Token: $CIRCLE_TOKEN" -X GET "https://circleci.com/api/v2/workflow/$CIRCLE_WORKFLOW_ID")

  echo "Getting CI pipeline info..."
  CIRCLE_PIPELINE_INFO=$(curl -s -H "Accept: application/json" -H "Circle-Token: $CIRCLE_TOKEN" -X GET "https://circleci.com/api/v2/pipeline/$(jq -r ".pipeline_id" <<< ${CIRCLE_WORKFLOW_INFO})")

  echo "Getting build archive download URL.."
  DOWNLOAD_URL=$(curl -s -H "Accept: application/json" -H "Circle-Token: $CIRCLE_TOKEN" -X GET "https://circleci.com/api/v2/project/$(jq -r ".project_slug" <<< ${CIRCLE_WORKFLOW_INFO})/$CIRCLE_BUILD_NUM/artifacts" | jq '.items[0].url' | tr -d '"')

  CIRCLE_JOB_URL="https://app.circleci.com/pipelines/$(jq -r '.project_slug' <<< ${CIRCLE_WORKFLOW_INFO})/$(jq -r '.pipeline_number' <<< ${CIRCLE_WORKFLOW_INFO})/workflows/$CIRCLE_WORKFLOW_ID"
  GH_REPO_URL=$(jq -r '.vcs.origin_repository_url' <<< ${CIRCLE_PIPELINE_INFO})

  _get_plugin_name $1 PLUGIN_NAME
  _get_plugin_version $1 PLUGIN_VERSION

  result=$(curl -s -H "Authorization: $GV_RELEASE_MANAGER_TOKEN" \
       -X POST \
       -F "plugin_name=$PLUGIN_NAME" \
       -F "plugin_version=$PLUGIN_VERSION" \
       -F "gh_commit_tag=$GH_COMMIT_TAG" \
       -F "gh_commit_url=$GH_REPO_URL/commit/$GH_COMMIT_HASH" \
       -F "gh_commit_timestamp=$GH_COMMIT_TIMESTAMP" \
       -F "download_url=$DOWNLOAD_URL" \
       -F "ci_job_url=$CIRCLE_JOB_URL" \
       $GV_RELEASE_MANAGER_URL
       )

  [ "$result" != 'true' ] && _abort "ERROR: could not notify the GravityView Release Manager server: $result"

  echo "SUCCESS: build information was pushed to the GravityView Release Manager server"
}

######################### Runtime magic :)
set -e

if [ -z "$1" ]; then
  HELP=$(cat <<-END
${BANNER}

Available commands:
    php                                 Run PHP
    grunt                               Run Grunt
    npm                                 Run npm
    plugin_name                         Return plugin name
    plugin_version                      Return plugin version
    package_build                       Create a release archive
    announce_build                      Send build information to GravityView Release Manager

    (use -o to pass optional parameters to the command)
END
)
  _abort "$HELP"
else
  _do_preflight_check

  while (( "$#" )); do
    case "$1" in
      -o)
        shift 2
        ;;
      *)
        if [[ "$1" =~ "--" ]]; then
          shift
        elif ! declare -f "$1" > /dev/null; then
          _abort "ERROR: $1 command does not exist"
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
