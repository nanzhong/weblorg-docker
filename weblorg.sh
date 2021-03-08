#!/usr/bin/env bash
#
# weblorg.sh is a helper script for using the emacs weblorg package.
#
# It primarily simplifies the automatic re-building on file changes and serving
# of the resulting static site.

set -euo pipefail

# workspace is where the base directory where the weblorg site is expected.
# default: /workspace.
workspace="${WORKSPACE:-/workspace}"
# pre_build_script is the path to the script to run before a build.
# default: pre.sh
pre_build_script="${PRE_BUILD_SCRIPT:-pre.sh}"
# post_build_script is the path to the script to run after a build.
# default: post.sh
post_build_script="${POST_BUILD_SCRIPT:-post.sh}"
# weblorg_defn is the emacs lisp file that defines the weblorg site.
# default: publish.el
weblorg_defn="${WEBLORG_DEFN:-publish.el}"
# weblorg_output_path is path where the weblorg site will be output to.
# default: output
weblorg_output_path="${WEBLORG_OUTPUT_PATH:-output}"

# run starts running a named command making sure to format stdout and stderr of
# the command with descriptive line prefixes.
# arguments: name, command, [arg1 arg2 ...]
function run() {
    "${@:2}" > >(prepend "$1 [stdout]") 2> >(prepend "$1 [stderr]" >&2)
}

# prepend reads line on stdin and prepends a prefix to each line.
# arguments: prefix
function prepend() {
    while read -r line; do
        if [[ -n "$line" ]]; then
            echo "$1 > $line"
        fi
    done
}

# build starts the weblorg build process
# globals: $pre_build_script, $post_build_script, $weblorg_defn
function build() {
    echo "=> Kicking off build..."

    if [[ -f "$pre_build_script" ]]; then
        echo "==> Detected pre-build script..."

        if [[ -x "$pre_build_script" ]]; then
            run "pre" "./$pre_build_script" || true
        else
            echo "==> Pre-build script is not executable, skipping."
        fi
    fi

    echo "=> Exporting via weblorg..."
    run "emacs" emacs --script "$weblorg_defn" || true

    if [[ -f "$post_build_script" ]]; then
        echo "==> Detected post-build script..."

        if [[ -x "$post_build_script" ]]; then
            run "post" "./$post_build_script" || true
        else
            echo "==> Post-build script is not executable, skipping."
        fi
    fi
}

# dev starts a caddy file server to serve the built weblorg site and watches the
# workspace for file changes to trigger rebuilds.
# globals: $weblorg_output_path
function dev() {
    mkdir -p "$weblorg_output_path"

    # start the file server
    run "www" caddy file-server --root "$weblorg_output_path" --access-log &

    # kick off an initial build
    build

    # start the file watcher
    echo "=> Configuring inotify watcher for changes on $workspace..."
    while true; do
        changes=()
        while read -r -t 1 change; do
            changes+=("$change")
        done

        if [[ "${#changes[@]}" -ne 0 ]]; then
            echo "=> Detected changes, kicking off build..."
            for change in "${changes[@]}"; do
                echo "==> $change"
            done
            build &
        fi
    done < <(inotifywait --monitor \
                         --recursive \
                         --exclude '\..+' \
                         --event modify \
                         --event move \
                         --event create \
                         --event delete \
                         --event attrib \
                         "$workspace")
}

# main is the main body of the script
# globals: $workspace
function main() {
    trap 'exit' TERM INT
    trap 'kill 0' EXIT

    command="$1"
    case $command in
        "" | "-h" | "--help")
            echo "Usage: weblorg build|dev"
            echo "  build: performs a one time build"
            echo "  dev:   builds, starts a file server, and watches file changes to trigger rebuilds"
            ;;
        build)
            echo "=> Starting a one off build..."
            build
            ;;
        dev)
            echo "=> Starting development..."
            dev
            ;;
        *)
            echo "Error: '$command' is not a supported command." >&2
            echo "       Run 'weblorg --help' for a list of commands ." >&2
            exit 1
            ;;
    esac
}

main "$@"
