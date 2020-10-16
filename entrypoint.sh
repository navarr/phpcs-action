#!/bin/sh
set -euo pipefail

cp /action/problem-matcher.json /github/workflow/problem-matcher.json

echo "::add-matcher::${RUNNER_TEMP}/_github_workflow/problem-matcher.json"

if [ "${INPUT_ONLY_CHANGED_FILES}" = "true" ]; then
    echo "Will only check changed files"
    # Per-page limits to 100 per page.  If more is needed in the future, we'll have to implement paging
    URL="$(jq -r '.pull_request._links.self.href' "${GITHUB_EVENT_PATH}")/files?per_page=100"

    CURL_RESULT=$(curl -s -H "Authorization: Bearer ${INPUT_TOKEN}" "${URL}")
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
