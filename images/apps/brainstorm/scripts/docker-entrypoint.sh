#!/bin/bash

SCRIPT_PATH=/apps/$APP_NAME/scripts

#$SCRIPT_PATH/check-dri.sh $CARD
#retVal=$?
#if [ $retVal -ne 0 ]; then
#  exit $retVal
#fi

$SCRIPT_PATH/create-user.sh $HIP_USER $APP_NAME
retVal=$?
if [ $retVal -ne 0 ]; then
  echo "return value is $retVal"
  exit $retVal
fi

#$SCRIPT_PATH/fix-video-groups.sh $CARD $HIP_USER
#retVal=$?
#if [ $retVal -ne 0 ]; then
#  exit $retVal
#fi

##copy configuration files to $HIP_USER account
#$SCRIPT_PATH/copy-config.sh $HIP_USER ${CONFIG_ARRAY[@]}
#retVal=$?
#if [ $retVal -ne 0 ]; then
#  exit $retVal
#fi

##mount docker-fs share for $HIP_USER
#if [ "$DOCKERFS_TYPE" = "davfs2" ]; then
#  $SCRIPT_PATH/mount-davfs2.sh $HIP_USER $HIP_PASSWORD $NEXTCLOUD_DOMAIN
#  retVal=$?
#elif [ "$DOCKERFS_TYPE" = "ghostfs" ]; then
#  $SCRIPT_PATH/mount-ghostfs.sh $HIP_USER $HIP_PASSWORD $NEXTCLOUD_DOMAIN
#  retVal=$?
#else
#  exit 1
#fi
#if [ $retVal -ne 0 ]; then
#  exit $retVal
#fi

#if [ "$DOCKERFS_TYPE" = "davfs2" ]; then
#  HIP_GROUP="davfs2"
#else
#  HIP_GROUP=$HIP_USER
#fi

##symlink app_data directories in $HIP_USER homedir
#$SCRIPT_PATH/homedir-symlink.sh $HIP_USER $HIP_GROUP app_data ${APP_DATA_DIR_ARRAY[@]}
#retVal=$?
#if [ $retVal -ne 0 ]; then
#  exit $retVal
#fi

##symlink data directories in $HIP_USER homedir
#$SCRIPT_PATH/homedir-symlink.sh $HIP_USER $HIP_GROUP data ${DATA_DIR_ARRAY[@]}
#retVal=$?
#if [ $retVal -ne 0 ]; then
#  exit $retVal
#fi

#run $APP_NAME as $HIP_USER
$SCRIPT_PATH/run-app.sh
retVal=$?
if [ $retVal -ne 0 ]; then
  exit $retVal
fi

##umount docker-fs share for $HIP_USER
#if [ "$DOCKERFS_TYPE" = "davfs2" ]; then
#  $SCRIPT_PATH/umount-davfs2.sh $HIP_USER
#  retVal=$?
#elif [ "$DOCKERFS_TYPE" = "ghostfs" ]; then
#  $SCRIPT_PATH/umount-ghostfs.sh $HIP_USER
#  retVal=$?
#else
#  exit 1
#fi
#if [ $retVal -ne 0 ]; then
#  exit $retVal
#fi
