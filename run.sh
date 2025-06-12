#!/bin/bash

PORT=$1
declare -a SCAN_PARAM=()
IS_HTTP=false
while (( "$#" )); do
    shift  # ignoring the first argument (already assigned)
    if [ -n "$1" ]; then
        SCAN_PARAM+=("-r")
        SCAN_PARAM+=("$1")
    fi
    if [[ "$1" == "http" ]]; then
        IS_HTTP=true
    fi
done
if [ "${IS_HTTP}" = true ]; then
    SCAN_PARAM+=("--http-extended-output")
fi

TIMESTAMP=$(TZ=":UTC" date '+%Y%m%d%H%M%S')
YEAR=$(TZ=":UTC" date '+%Y')
MONTH=$(TZ=":UTC" date '+%m')
DAY=$(TZ=":UTC" date '+%d')

SHARED_DIR="shared_dir"
INPUT_DIR="${SHARED_DIR}/input"
INPUT_LINK_NAME="input_link_${PORT}_${TIMESTAMP}.txt"  # contains which input/allowlist was used for this scan
INPUT_LINK="${INPUT_DIR}/${INPUT_LINK_NAME}"
OUTPUT_DIR="${SHARED_DIR}/output"
CONFIG_FILE_NAME="goscanner.conf"
STORED_CONFIG_FILE_NAME="goscanner_${PORT}_${TIMESTAMP}.conf"
CONFIG_FILE="${INPUT_DIR}/${CONFIG_FILE_NAME}"
LOG_FILE_NAME="log_${PORT}_${TIMESTAMP}.json"
LOG_FILE="${SHARED_DIR}/${LOG_FILE_NAME}"
TIME_FILE_NAME="time_${PORT}_${TIMESTAMP}.txt"
TIME_OUTPUT="${SHARED_DIR}/${TIME_FILE_NAME}"
SCAN_ERROR_NAME="error_${PORT}_${TIMESTAMP}.txt"
SCAN_ERROR="${SHARED_DIR}/${SCAN_ERROR_NAME}"
ALIAS_NAME="goscanner-write"
ARTEFACT_OBJSTORE_PATH="${ALIAS_NAME}/catrin/artefacts/tool=goscanner/port=${PORT}/year=${YEAR}/month=${MONTH}/day=${DAY}"
USER=$(id -u)

# should we need it
echo "Cleaning..."
rm -rf "${OUTPUT_DIR}"
# docker creates everything under root user. Hence, we must clean output_dir as root user
docker run --rm -v "$(pwd)"/${SHARED_DIR}:/root/${SHARED_DIR} alpine rm -rf /root/"${OUTPUT_DIR}"
rm -f "${INPUT_DIR}"/*.csv

echo "Retrieve allowlist..."
docker run --network=host -v "$(pwd)"/${SHARED_DIR}:/root/${SHARED_DIR} --rm goscanner-file-manager --download --timestamp "${YEAR}${MONTH}${DAY}" --port "${PORT}"
# prepare allowlist to include port number
INPUT_FILE=$(ls "${INPUT_DIR}"/*.csv)
tail -n +2 "${INPUT_FILE}" > "${INPUT_FILE}.tmp" && mv -f "${INPUT_FILE}.tmp" "${INPUT_FILE}"
sed -e "s/$/:${PORT}/" -i "${INPUT_FILE}"

echo "Scanning..."
{ time \
    docker run --user "${USER}" --network=host -v "$(pwd)"/${SHARED_DIR}:/go/${SHARED_DIR} --rm --name goscanner goscanner -C "${CONFIG_FILE}" "${SCAN_PARAM[@]}" -i "${INPUT_FILE}" -l "${LOG_FILE}" 2> "${SCAN_ERROR}";
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
    docker run --rm mail bash -c "echo '${BODY}' | mutt -s '${SUBJECT}' ${RECIPIENT}"
fi

echo "Uploading scan data..."
docker run --network=host -v "$(pwd)"/${SHARED_DIR}:/root/${SHARED_DIR} --rm goscanner-file-manager --upload --port "${PORT}" --output-scan-dir "${OUTPUT_DIR}"
#docker run --network=host -v "$(pwd)"/${SHARED_DIR}:/root/${SHARED_DIR} --rm  mc mv "${LOG_FILE}" "${ARTEFACT_OBJSTORE_PATH}"/"${LOG_FILE_NAME}"

echo "Uploading artefacts..."
mc mv "${LOG_FILE}" "${ARTEFACT_OBJSTORE_PATH}"/"${LOG_FILE_NAME}"
#podman run --network=host -v "$(pwd)"/${SHARED_DIR}:/root/${SHARED_DIR} --rm  mc cp "${CONFIG_FILE}" "${ARTEFACT_OBJSTORE_PATH}"/"${CONFIG_FILE_NAME}"
mc cp "${CONFIG_FILE}" "${ARTEFACT_OBJSTORE_PATH}"/"${STORED_CONFIG_FILE_NAME}"
echo "${INPUT_FILE}" > "${INPUT_LINK}"
#podman run --network=host -v "$(pwd)"/${SHARED_DIR}:/root/${SHARED_DIR} --rm  mc mv "${INPUT_LINK}" "${ARTEFACT_OBJSTORE_PATH}"/"${INPUT_LINK_NAME}"
mc mv "${INPUT_LINK}" "${ARTEFACT_OBJSTORE_PATH}"/"${INPUT_LINK_NAME}"
#podman run --network=host -v "$(pwd)"/${SHARED_DIR}:/root/${SHARED_DIR} --rm  mc mv "${TIME_OUTPUT}" "${ARTEFACT_OBJSTORE_PATH}"/"${TIME_FILE_NAME}"
mc mv "${TIME_OUTPUT}" "${ARTEFACT_OBJSTORE_PATH}"/"${TIME_FILE_NAME}"
#podman run --network=host -v "$(pwd)"/${SHARED_DIR}:/root/${SHARED_DIR} --rm  mc mv "${SCAN_ERROR}" "${ARTEFACT_OBJSTORE_PATH}"/"${SCAN_ERROR_NAME}"
mc mv "${SCAN_ERROR}" "${ARTEFACT_OBJSTORE_PATH}"/"${SCAN_ERROR_NAME}"
