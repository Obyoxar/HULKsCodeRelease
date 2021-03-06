#!/bin/bash

source "${BASEDIR}/scripts/lib/logs.sh"
source "${BASEDIR}/scripts/lib/findnao.sh"
function upload {

  if [ "$#" -ne 6 ]; then
    return 1
  fi
  local BASEDIR="$1"

  local RSYNC_TARGET="$2"
  local TARGET_PORT="$3"
    findnao $RSYNC_TARGET
  if [ "$?" -ne 0 ]; then
    return 1
  fi
  local BUILD_TYPE="$4"
  local UPLOAD_CONFIG=$5
  local DELETE_FILES=$6
  # files that should be excluded
  local RSYNC_EXCLUDE="--exclude=*webots* --exclude=*.gitkeep --exclude=*.touch"
  # ssh login
  local SSH_USERNAME="nao"
  # path to the ssh key
  local SSH_KEY="${BASEDIR}/scripts/ssh_key"

  # create temp directory
  local TMP_DIR=`mktemp -d`
  if [ "$?" -ne 0 ]; then
    msg -e "Could not create temporary directory!"
    return 1
  fi

  # /home/nao/naoqi structure
  mkdir -p "${TMP_DIR}/naoqi"
  mkdir -p "${TMP_DIR}/naoqi/lib"
  mkdir -p "${TMP_DIR}/naoqi/bin"
  mkdir -p "${TMP_DIR}/naoqi/filetransport_ball_candidates"

  if ${UPLOAD_CONFIG}; then
    # ln -s "${BASEDIR}/home/preferences" "${TMP_DIR}/naoqi/preferences"
    ln -s "${BASEDIR}/home/configuration" "${TMP_DIR}/naoqi/configuration"
  fi
  #ln -s "${BASEDIR}/home/motions" "${TMP_DIR}/naoqi/motions"
  #ln -s "${BASEDIR}/home/poses"   "${TMP_DIR}/naoqi/poses"

  ln -s "${BASEDIR}/build/nao/${BUILD_TYPE}/src/launcher/launcher" "${TMP_DIR}/naoqi/bin/launcher"
  ln -s "${BASEDIR}/build/nao/${BUILD_TYPE}/src/core/libDuckburg.so" "${TMP_DIR}/naoqi/lib/"
  ln -s "${BASEDIR}/home/launch.sh" "${TMP_DIR}/naoqi/launch.sh"
  ln -s ${BASEDIR}/build/nao/${BUILD_TYPE}/src/engines/lib*.so ${TMP_DIR}/naoqi/lib/   # quotation marks removed because of glob regex
  # ssh wants the key permissions to be like that
  if [ -e "${SSH_KEY}" ]; then
    chmod 400 "${SSH_KEY}"
  fi

  # ssh connection command with parameters; check also the top config part
  local SSH_CMD="ssh -p $TARGET_PORT -q -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -l ${SSH_USERNAME} -i \"${SSH_KEY}\""

  # parameters for rsync
  local RSYNC_PARAMETERS="-trzKLP ${RSYNC_EXCLUDE}"
  if ${DELETE_FILES}; then
    RSYNC_PARAMETERS+=" --delete --delete-excluded"
    delete_logs $BASEDIR $RSYNC_TARGET
  fi

  # run rsync with prepared parameters
  rsync ${RSYNC_PARAMETERS} --rsh="${SSH_CMD}" "${TMP_DIR}/naoqi" "${RSYNC_TARGET}:"
  local RSYNC_RESULT=$?

  # clean temp directory
  rm -rf "${TMP_DIR}"

  return $RSYNC_RESULT
}
