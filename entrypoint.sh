#!/bin/bash
set -eo
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

INPUT_ONLY_CHANGED_FILES=${INPUT_ONLY_CHANGED_FILES:-${INPUT_ONLY_CHANGED_LINES:-"false"}}

if [ "${GITHUB_EVENT_NAME}" = "pull_request" ]; then
    COMPARE_FROM=origin/${GITHUB_BASE_REF}
    COMPARE_TO=origin/${GITHUB_HEAD_REF}

    COMPARE_FROM_REF=$(git merge-base "${COMPARE_FROM}" "${COMPARE_TO}")
    COMPARE_TO_REF=${COMPARE_TO}
else
    COMPARE_FROM="HEAD^"
    COMPARE_TO="HEAD"
    COMPARE_FROM_REF="HEAD^"
    COMPARE_TO_REF="HEAD"
fi

if [ "${INPUT_ONLY_CHANGED_FILES}" = "true" ]; then
    echo "Will only check changed files" 
    set +e
    CHANGED_FILES=$(git diff --name-only "${COMPARE_FROM_REF}" "${COMPARE_TO_REF}" | xargs -rt ls -1d 2>/dev/null)
    set -e
    echo "Will check files:"
    echo "${CHANGED_FILES}"
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
    if [ "${INPUT_ONLY_CHANGED_LINES}" = "true" ]; then
        step1=$(git diff -U0 "${COMPARE_FROM_REF}" "${COMPARE_TO_REF}")
        step2=$(echo "${step1}" | diff-lines)
        step3=$(echo "${step2}" | grep -ve ':-')
        step4=$(echo "${step3}" | sed 's/:+.*//') # On some platforms, sed needs to have + escaped.  This isn't the case for Alpine sed.
        set +e
        echo "${CHANGED_FILES}" | xargs -rt ${INPUT_PHPCS_BIN_PATH} ${ENABLE_WARNINGS_FLAG} --report=checkstyle | filter-by-changed-lines "${step4}"
        status=$?
        set -e
    else
        echo "${CHANGED_FILES}" | xargs -rt ${INPUT_PHPCS_BIN_PATH} ${ENABLE_WARNINGS_FLAG} --report=checkstyle
        status=$?
    fi
else
    echo "::add-matcher::${{ github.action_path }}/problem-matcher.json"
    ${INPUT_PHPCS_BIN_PATH} ${ENABLE_WARNINGS_FLAG} --report=checkstyle
    echo "::remove-matcher owner=phpcs::"
    status=$?
fi

exit $status
