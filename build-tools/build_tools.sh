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
  ( docker run --rm \
    --env TX_TOKEN=${TX_TOKEN} \
    --user $(id -u):$(id -g) \
    --volume /etc/passwd:/etc/passwd:ro \
    --volume /etc/group:/etc/group:ro \
    --volume $PWD:/app \
    --volume $HOME:$HOME \
    gravityview/build_environment "$@"
  ) || _abort "ERROR: Docker exited with an error"
}

_get_plugin_version() {
  [ -z "$1" ] || ! [ -s "$1" ] && _abort "ERROR: $1 plugin file not found"

  PLUGIN_VERSION=$(cat $1 | grep -m1 -Po '(?<=Version:).*' | tr -d "  " | sed -e 's/^[[:space:]]*//')

  [ -z "$PLUGIN_VERSION" ] && _abort "ERROR: plugin version could not be found inside $PWD/$1"

  eval "$2='$PLUGIN_VERSION'"
}

_get_plugin_name() {
  [ -z "$1" ] || ! [ -s "$1" ] && _abort "ERROR: $1 plugin file not found"

  PLUGIN_NAME=$(cat $1 | grep -m1 -Po '(?<=Name:).*' | sed -e 's/^[[:space:]]*//')

  [ -z "$PLUGIN_NAME" ] && _abort "ERROR: plugin name could not be found inside $PWD/$1"

  eval "$2='$PLUGIN_NAME'"
}

######################### Available commands
php() {
  _run_docker php "$@"
}

composer() {
  _run_docker composer "$@"
}

grunt() {
  _run_docker grunt "$@"
}

npm() {
  _run_docker npm "$@"
}

yarn() {
  _run_docker yarn "$@"
}

tx() {
  _run_docker tx "$@"
}

gh() {
  _run_docker gh "$@"
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

Required syntax: package_build -o "build_prefix plugin_file.php --include-hash"

    build_prefix                       Build prefix (e.g., "gravityview" will result in "gravityview-<version>.zip" file)
    plugin_file                        Main plugin file (e.g., "gravityview.php")
    (optional) --include-hash          Commit hash will be included in the build name (e.g., "gravityview-<version>-<commit>.zip")
END
)

  [ -z "${args[0]}" ] || [ -z "${args[1]}" ] || ! [ -s ${args[1]} ] && _abort "$HELP"

  GH_COMMIT_HASH='' && [[ "$*" =~ "--include-hash" ]] && GH_COMMIT_HASH="-$(git log --pretty=format:'%h' -n 1)"

  _get_plugin_version "${args[1]}" PLUGIN_VERSION

  BUILD_FILE="${args[0]}-$PLUGIN_VERSION$GH_COMMIT_HASH.zip"

  LATEST_CHANGES=`git stash create`; git archive --format=zip --prefix=${args[0]}/ --output=$BUILD_FILE ${LATEST_CHANGES:-HEAD}

  ! [ -s ${args[1]} ] && _abort "ERROR: $BUILD_FILE is empty"

  echo "SUCCESS: $BUILD_FILE was created"
}

announce_build() {
      HELP=$(cat <<-END
${BANNER}

Required syntax: announce_build -o "plugin_file.php build_file.zip"

    plugin_file                        Main plugin file (e.g., "gravityview.php")
    build_file                         Build file (e.g., "gravityview-<version>.zip")
    (optional) --with-circle           Include CircleCI build information (requires CIRCLE_TOKEN, CIRCLE_WORKFLOW_ID, CIRCLE_BUILD_NUM environment variables)

NOTE: GV_RELEASE_MANAGER_URL and GV_RELEASE_MANAGER_TOKEN environment variables must be set
END
)

  args=($1)

  [ -z "${args[0]}" ] || [ -z "${args[1]}" ] && _abort "$HELP"
  ! [ -s "${args[1]}" ] || ! [ -s "${args[0]}" ] && _abort "ERROR: $PWD/${args[1]} not found"

  WITH_CIRCLE='' && [[ "$*" =~ "--with-circle" ]] && WITH_CIRCLE="true"

  REQUIRED_VARS=(GV_RELEASE_MANAGER_URL GV_RELEASE_MANAGER_TOKEN)
  [[ $WITH_CIRCLE == "true" ]] && REQUIRED_VARS+=(CIRCLE_TOKEN CIRCLE_WORKFLOW_ID CIRCLE_BUILD_NUM)

  for required_var in ${REQUIRED_VARS[*]}
  do
    [ -z "${!required_var}" ] && _abort "ERROR: $required_var environment variable is not set"
  done

  GH_COMMIT_TIMESTAMP=$(git log --pretty=format:'%at' -n 1)
  GH_COMMIT_HASH=$(git log --pretty=format:'%h' -n 1)
  GH_COMMIT_TAG=$(git tag --points-at HEAD)
  GH_REPO_URL=$(git remote get-url origin | sed 's/\.git//' | sed 's/git@github.com:/https:\/\/github.com\//')

  if [[ $WITH_CIRCLE == "true" ]]; then
    echo "Getting CI workflow info..."
    CIRCLE_WORKFLOW_INFO=$(curl -s -H "Accept: application/json" -H "Circle-Token: $CIRCLE_TOKEN" -X GET "https://circleci.com/api/v2/workflow/$CIRCLE_WORKFLOW_ID")

    echo "Getting CI build file download URL.."
    CIRCLE_DOWNLOAD_URL=$(curl -s -H "Accept: application/json" -H "Circle-Token: $CIRCLE_TOKEN" -X GET "https://circleci.com/api/v2/project/$(jq -r ".project_slug" <<< ${CIRCLE_WORKFLOW_INFO})/$CIRCLE_BUILD_NUM/artifacts" | jq '.items[0].url' | tr -d '"')

    CIRCLE_JOB_URL="https://app.circleci.com/pipelines/$(jq -r '.project_slug' <<< ${CIRCLE_WORKFLOW_INFO})/$(jq -r '.pipeline_number' <<< ${CIRCLE_WORKFLOW_INFO})/workflows/$CIRCLE_WORKFLOW_ID"
  fi

  BUILD_FILE=${args[1]}
  BUILD_HASH=$(md5sum $BUILD_FILE | cut -d ' ' -f1)

  _get_plugin_name ${args[0]} PLUGIN_NAME
  _get_plugin_version ${args[0]} PLUGIN_VERSION

  result=$(curl -s -H "Authorization: $GV_RELEASE_MANAGER_TOKEN" \
       -X POST \
       -F "plugin_name=$PLUGIN_NAME" \
       -F "plugin_version=$PLUGIN_VERSION" \
       -F "gh_commit_tag=$GH_COMMIT_TAG" \
       -F "gh_commit_url=$GH_REPO_URL/commit/$GH_COMMIT_HASH" \
       -F "gh_commit_timestamp=$GH_COMMIT_TIMESTAMP" \
       -F "build_file=@$BUILD_FILE" \
       -F "build_hash=$BUILD_HASH" \
       -F "ci_job_url=$CIRCLE_JOB_URL" \
       -F "ci_download_url=$CIRCLE_DOWNLOAD_URL" \
       $GV_RELEASE_MANAGER_URL
       )

  [ "$result" != 'true' ] && _abort "ERROR: failed to notify the GravityView Release Manager server: $result"

  echo "SUCCESS: build information was pushed to the GravityView Release Manager server"
}

create_release() {
  HELP=$(cat <<-END
${BANNER}

Required syntax: create_release -o "plugin_file.php build_file.zip"

    plugin_file                        Main plugin file (e.g., "gravityview.php")
    build_file                         Build file (e.g., "gravityview-<version>.zip")

NOTE: GH_AUTH_TOKEN environment variable must be set
END
)

  args=($1)

  [ -z "${args[0]}" ] || [ -z "${args[1]}" ] && _abort "$HELP"
  ! [ -s "${args[0]}" ] || ! [ -s "${args[1]}" ] && _abort "ERROR: $PWD/${args[0]} not found"

  if [[ $(git log -n 1 | grep "\[skip release\]") ]]; then
    echo "Skipping release..."
    return
  fi

  _get_plugin_version ${args[0]} PLUGIN_VERSION

  RELEASE_TAG="v$PLUGIN_VERSION"
  GH_CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
  REMOTE_BRANCHES_TO_UPDATE=$GH_CURRENT_BRANCH

  [ -z "$GH_AUTH_TOKEN" ] && _abort "ERROR: GH_AUTH_TOKEN (Github) environment variable is not set"
  gh "auth login --with-token <<< $GH_AUTH_TOKEN"

  # Oh no! A tag with release version already exists!
  if ! [ -z "$(git tag -l $RELEASE_TAG)" ]; then
    # Are we forcing a release?
    [[ $(git log -n 1 | grep "\[force release\]") ]] || _abort "ERROR: $RELEASE_TAG release already exists"

    echo "Untagging/deleting existing release..."

    # Untag locally
    git tag -d $RELEASE_TAG

    # Maybe delete remote tag
    [[ $(git ls-remote --refs origin | grep $RELEASE_TAG) ]] && git push --delete origin $RELEASE_TAG

    # Maybe delete remote release
    [[ $(gh release list | grep $RELEASE_TAG) ]] && gh release delete $RELEASE_TAG
  fi

  if [[ $(git ls-files --modified) ]]; then
    echo "Committing changes..."

    # Add/commit modified files
    git add -u
    git commit -m "Add updated translations/assets & release $RELEASE_TAG [ci skip]"

    # Maybe update develop branch
    if [[ $(git branch -a | grep remotes/origin/develop) ]] && [[ $GH_CURRENT_BRANCH != 'develop' ]]; then
      REMOTE_BRANCHES_TO_UPDATE+=" develop"

      git checkout develop
      git cherry-pick $GH_CURRENT_BRANCH
      git checkout $GH_CURRENT_BRANCH
    fi
  fi
  echo "Tagging and pushing changes..."

  # Tag new version
  git tag -a $RELEASE_TAG HEAD -m "Release $RELEASE_TAG"

  # Push tag & update remote branches
  git push --atomic origin $REMOTE_BRANCHES_TO_UPDATE $RELEASE_TAG

  echo "Creating a release.."

  # Extract text between 2 patterns, remove first/last empty lines, and escape quotes/backticks
  RELEASE_NOTES=$(sed -nE "/= $PLUGIN_VERSION /{:s n;/= /q;p;bs}" readme.txt | sed '1{/^$/d};${/^$/d}' | sed 's/[`"]/\\&/g')

  # Create a GH release (make it a pre-release if the version contains anything but a period or numbers)
  gh release create $([[ $PLUGIN_VERSION =~ ^[0-9.]+$ ]] || echo "-p") -t $PLUGIN_VERSION -n \""$RELEASE_NOTES"\" $RELEASE_TAG ${args[1]}

  # Just in case... make sure the release was created
  [[ $(gh release list | grep $RELEASE_TAG) ]] || _abort "ERROR: GitHub release was not created"

  echo "SUCCESS: released!"
}

######################### Runtime magic :)
set -e

if [ -z "$1" ]; then
  HELP=$(cat <<-END
${BANNER}

Available commands:
    php                                 Run PHP
    composer                            Run Composer
    grunt                               Run Grunt
    npm                                 Run npm
    yarn                                Run Yarn
    tx                                  Run Transifex client
    gh                                  Run GitHub CLI
    plugin_name                         Return plugin name
    plugin_version                      Return plugin version
    package_build                       Create a build file
    announce_build                      Send build information to GravityView Release Manager
    create_release                      Create GitHub release

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
