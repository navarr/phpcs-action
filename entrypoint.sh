#!/bin/bash
set -euo
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
    local exitCode=0

    echo "Debug Changed Lines:"
    echo "${changedLines[*]}"
    echo "End Debug"

    while read -r line; do
        if [[ $line =~ \<file\ name=\"(\/github\/workspace\/)?([^\"]+) ]]; then
            fileName=${BASH_REMATCH[2]}
            echo "${line}"
        elif [[ $line =~ \<error\ line=\"([^\"]+) ]]; then
            fileLine=${BASH_REMATCH[1]}
            if [[ "${changedLines[*]}" =~ "${fileName}:${fileLine}" ]]; then
                exitCode=1
                echo "${line}"
            fi
        else
            echo "${line}"
        fi
    done
    exit $exitCode
}

COMPARE_FROM=origin/${GITHUB_HEAD_REF}
COMPARE_TO=origin/${GITHUB_BASE_REF}

COMPARE_FROM_REF=${COMPARE_FROM}
COMPARE_TO_REF=$(git merge-base "${COMPARE_FROM}" "${COMPARE_TO}")

cp /action/problem-matcher.json /github/workflow/problem-matcher.json

echo "::add-matcher::${RUNNER_TEMP}/_github_workflow/problem-matcher.json"

if [ "${INPUT_ONLY_CHANGED_FILES}" = "true" ]; then
    echo "Will only check changed files"
    if [ "${GITHUB_EVENT_NAME}" = "pull_request" ]; then
        CHANGED_FILES=$(git diff --name-only "${COMPARE_FROM_REF}" "${COMPARE_TO_REF}")
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
    echo "DEBUG DIFF U0"
    step1=$(git diff -U0 "${COMPARE_FROM_REF}" "${COMPARE_TO_REF}")
    echo "${step1}"
    echo "DEBUG DIFF-LINES"
    step2=$(echo "${step1}" | diff-lines)
    echo "${step2}"
    echo "DEBUG GREP"
    step3=$(echo "${step2}" | grep -ve ':-')
    echo "${step3}"
    echo "DEBUG SED"
    step4=$(echo "${step3}" | sed 's/:+.*//')
    echo "${step4}"
    set +e # we want to potentially change the error code
    echo "${CHANGED_FILES}" | xargs -rt ${INPUT_PHPCS_BIN_PATH} ${ENABLE_WARNINGS_FLAG} --report=checkstyle | filter-by-changed-lines "${step4}"
else
    ${INPUT_PHPCS_BIN_PATH} ${ENABLE_WARNINGS_FLAG} --report=checkstyle
fi

status=$?

echo "::remove-matcher owner=phpcs::"

exit $status
