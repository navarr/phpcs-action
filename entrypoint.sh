#!/bin/bash
set -euo pipefail
diff-lines() {
    local path=
    local line=
    while read; do
        esc=$'\033'
        if [[ $REPLY =~ ---\ (a/)?.* ]]; then
            continue
        elif [[ $REPLY =~ \+\+\+\ (b/)?([^[:blank:]$esc]+).* ]]; then
            path=${BASH_REMATCH[2]}
        elif [[ $REPLY =~ @@\ -[0-9]+(,[0-9]+)?\ \+([0-9]+)(,[0-9]+)?\ @@.* ]]; then
            line=${BASH_REMATCH[2]}
        elif [[ $REPLY =~ ^($esc\[[0-9;]*m)*([\ +-]) ]]; then
            echo "$path:$line:$REPLY"
            if [[ ${BASH_REMATCH[2]} != - ]]; then
                ((line++))
            fi
        fi
    done
}
filter-by-changed-lines() {
    changedLines=$1;
    local fileName=
    local fileLine=
    while read -r line; do
        if [[ $line =~ \<file\ name=\"(\/github\/workspace\/)?([^\"]+) ]]; then
            fileName=${BASH_REMATCH[2]}
            echo "${line}"
        elif [[ $line =~ \<error\ line=\"([^\"]+) ]]; then
            fileLine=${BASH_REMATCH[1]}
            if [[ "${changedLines[*]}" =~ "${fileName}:${fileLine}" ]]; then
                echo "${line}"
            fi
        else
            echo "${line}"
        fi
    done
}

cp /action/problem-matcher.json /github/workflow/problem-matcher.json

echo "::add-matcher::${RUNNER_TEMP}/_github_workflow/problem-matcher.json"

if [ "${INPUT_ONLY_CHANGED_FILES}" = "true" ]; then
    echo "Will only check changed files"
    if [ "${GITHUB_EVENT_NAME}" = "pull_request" ]; then
        CHANGED_FILES=$(git diff --name-only "${GITHUB_HEAD_REF}" "${GITHUB_BASE_REF}")
    else
        CHANGED_FILES=$(git diff --name-only)
    fi
else
    echo "Will check all files"
fi

if [ -n "${INPUT_INSTALLED_PATHS}" ]; then
    ${INPUT_PHPCS_BIN_PATH} --config-set installed_paths "${INPUT_INSTALLED_PATHS}"
fi

if [ -z "${INPUT_ENABLE_WARNINGS}" ] || [ "${INPUT_ENABLE_WARNINGS}" = "false" ]; then
    echo "Check for warnings disabled"
    ENABLE_WARNINGS_FLAG="-n"
else
    echo "Check for warnings enabled"
    ENABLE_WARNINGS_FLAG=""
fi

set +e
if [ "${INPUT_ONLY_CHANGED_FILES}" = "true" ]; then
    echo "${CHANGED_FILES}" | xargs -rt ${INPUT_PHPCS_BIN_PATH} ${ENABLE_WARNINGS_FLAG} --report=checkstyle
else
    ${INPUT_PHPCS_BIN_PATH} ${ENABLE_WARNINGS_FLAG} --report=checkstyle | filter-by-changed-lines "$(git diff -U0 HEAD 'HEAD^^' | diff-lines | grep -ve ':-' | sed 's/:\+.*//')"
fi

status=$?

echo "::remove-matcher owner=phpcs::"

exit $status
