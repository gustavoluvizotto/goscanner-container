#!/bin/bash

PORT=$1
declare -a SCAN_PARAM=()
while (( "$#" )); do
    shift  # ignoring the first argument (already assigned)
    if [ -n "$1" ]; then
        SCAN_PARAM+=("-r")
        SCAN_PARAM+=("$1")
    fi
done

TIMESTAMP=$(TZ=":UTC" date '+%Y%m%d%H%M%S')
YEAR=$(TZ=":UTC" date '+%Y')
MONTH=$(TZ=":UTC" date '+%m')
DAY=$(TZ=":UTC" date '+%d')

SHARED_DIR="shared_dir"
INPUT_DIR="${SHARED_DIR}/input"
INPUT_LINK_NAME="input_link.txt"  # contains which input/allowlist was used for this scan
INPUT_LINK="${INPUT_DIR}/${INPUT_LINK_NAME}"
OUTPUT_DIR="${SHARED_DIR}/output"
CONFIG_FILE_NAME="goscanner.conf"
CONFIG_FILE="${INPUT_DIR}/${CONFIG_FILE_NAME}"
LOG_FILE_NAME="log_${TIMESTAMP}.json"
LOG_FILE="${SHARED_DIR}/${LOG_FILE_NAME}"
ALIAS_NAME="goscanner-write"
ARTEFACT_OBJSTORE_PATH="${ALIAS_NAME}/catrin/artefacts/tool=goscanner/year=${YEAR}/month=${MONTH}/day=${DAY}"
TIME_FILE_NAME="time_${PORT}_${TIMESTAMP}.txt"
TIME_OUTPUT="${SHARED_DIR}/${TIME_FILE_NAME}"
SCAN_ERROR_NAME="error_${TIMESTAMP}.txt"
SCAN_ERROR="${SHARED_DIR}/${SCAN_ERROR_NAME}"

# should we need it
echo "Cleaning..."
rm -rf "${OUTPUT_DIR}"
rm -f "${INPUT_DIR}"/*.csv

echo "Retrieve allowlist..."
podman run --network=host -v "$(pwd)"/${SHARED_DIR}:/root/${SHARED_DIR} --rm goscanner-file-manager --download --timestamp "${YEAR}${MONTH}${DAY}" --port "${PORT}"
# prepare allowlist to include port number
INPUT_FILE=$(ls "${INPUT_DIR}"/*.csv)
tail -n +2 "${INPUT_FILE}" > "${INPUT_FILE}.tmp" && mv "${INPUT_FILE}.tmp" "${INPUT_FILE}"
sed -e "s/$/:${PORT}/" -i "${INPUT_FILE}"

echo "Scanning..."
{ time \
    podman run --network=host -v "$(pwd)"/${SHARED_DIR}:/go/${SHARED_DIR} --rm --name goscanner goscanner -C "${CONFIG_FILE}" "${SCAN_PARAM[@]}" -i "${INPUT_FILE}" -l "${LOG_FILE}" 2> "${SCAN_ERROR}";
} 2> "${TIME_OUTPUT}"
ret=$?
if [ $ret != 0 ]; then
    E=$(cat "${SCAN_ERROR}")
    T=$(cat "${TIME_OUTPUT}")
    BODY="The Goscanner scan failed with ${ret} error code. The output files might not have been
         generated and hence, not uploaded to online storage. Scan parameters:
         ${SCAN_PARAM[*]}, input=${INPUT_FILE}, port=${PORT}.
         Error: ${E}. Time: ${T}"
    SUBJECT="Goscanner scan error at ${TIMESTAMP}"
    RECIPIENT="scan-notification@internet-transparency.org"
    podman run --rm mail bash -c "echo '${BODY}' | mutt -s '${SUBJECT}' ${RECIPIENT}"
fi

echo "Uploading scan data..."
podman run --network=host -v "$(pwd)"/${SHARED_DIR}:/root/${SHARED_DIR} --rm goscanner-file-manager --upload --port "${PORT}" --output-scan-dir "${OUTPUT_DIR}"
#podman run --network=host -v "$(pwd)"/${SHARED_DIR}:/root/${SHARED_DIR} --rm  mc mv "${LOG_FILE}" "${ARTEFACT_OBJSTORE_PATH}"/"${LOG_FILE_NAME}"
mc mv "${LOG_FILE}" "${ARTEFACT_OBJSTORE_PATH}"/"${LOG_FILE_NAME}"
#podman run --network=host -v "$(pwd)"/${SHARED_DIR}:/root/${SHARED_DIR} --rm  mc cp "${CONFIG_FILE}" "${ARTEFACT_OBJSTORE_PATH}"/"${CONFIG_FILE_NAME}"
mc cp "${CONFIG_FILE}" "${ARTEFACT_OBJSTORE_PATH}"/"${CONFIG_FILE_NAME}"
echo "${INPUT_FILE}" > "${INPUT_LINK}"
#podman run --network=host -v "$(pwd)"/${SHARED_DIR}:/root/${SHARED_DIR} --rm  mc mv "${INPUT_LINK}" "${ARTEFACT_OBJSTORE_PATH}"/"${INPUT_LINK_NAME}"
mc mv "${INPUT_LINK}" "${ARTEFACT_OBJSTORE_PATH}"/"${INPUT_LINK_NAME}"
#podman run --network=host -v "$(pwd)"/${SHARED_DIR}:/root/${SHARED_DIR} --rm  mc mv "${TIME_OUTPUT}" "${ARTEFACT_OBJSTORE_PATH}"/"${TIME_FILE_NAME}"
mc mv "${TIME_OUTPUT}" "${ARTEFACT_OBJSTORE_PATH}"/"${TIME_FILE_NAME}"
#podman run --network=host -v "$(pwd)"/${SHARED_DIR}:/root/${SHARED_DIR} --rm  mc mv "${SCAN_ERROR}" "${ARTEFACT_OBJSTORE_PATH}"/"${SCAN_ERROR_NAME}"
mc mv "${SCAN_ERROR}" "${ARTEFACT_OBJSTORE_PATH}"/"${SCAN_ERROR_NAME}"
