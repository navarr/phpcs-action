#!/bin/sh
set -euo pipefail

cp /action/problem-matcher.json /github/workflow/problem-matcher.json

echo "::add-matcher::${RUNNER_TEMP}/_github_workflow/problem-matcher.json"

if [ "${INPUT_ONLY_CHANGED_FILES}" = "true" ]; then
    echo "Will only check changed files"
    PR="$(jq -r '.pull_request.number' < "${GITHUB_EVENT_PATH}")"
    URL="https://api.github.com/repos/${GITHUB_REPOSITORY}/pulls/${PR}/files"
    AUTH="Authorization: Bearer ${INPUT_TOKEN}"

    CURL_RESULT=$(curl --request GET --url "${URL}" --header "${AUTH}")
    CHANGED_FILES=$(echo "${CURL_RESULT}" | jq -r '.[] | select(.status != "removed") | .filename')
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
    ${INPUT_PHPCS_BIN_PATH} ${ENABLE_WARNINGS_FLAG} --report=checkstyle
fi

status=$?

echo "::remove-matcher owner=phpcs::"

exit $status
