#!/bin/bash

HIP_USER=$1
APP_NAME=$2

echo -n "Creating user $HIP_USER... "

if [ "$APP_NAME" = "brainvisa" ] || [ "$APP_NAME" = "intranat" ]; then
  egrep "^brainvisa" /etc/passwd >/dev/null
  if [ $? -eq 0 ]; then
    userdel brainvisa
    if [ ! $? -eq 0 ]; then
      echo "failed."
      exit 1
    fi
    mv /home/brainvisa /home/$HIP_USER
    if [ ! $? -eq 0 ]; then
      echo "failed."
      exit 1
    fi
  fi
fi

egrep "^$HIP_USER" /etc/passwd >/dev/null
if [ $? -eq 0 ]; then
  echo "$HIP_USER already exists."
  exit 0
else
  useradd --create-home --shell /bin/bash $HIP_USER --uid 1000
  if [ $? -eq 0 ]; then
    echo "done."
  else
    echo "failed."
    exit 1
  fi
fi

#if [[ -d /apps/$APP_NAME/install ]]; then
#  echo -n "Giving group r/w access to /apps/$APP_NAME/install for $HIP_USER... "
#  #chgrp -R $HIP_USER /apps/$APP_NAME/install
#  #if [ $? -ne 0 ]; then
#  #  echo "failed."
#  #  exit 1
#  #fi
#  #chmod -R g+w /apps/$APP_NAME/install
#  chmod -R o+w /apps/$APP_NAME/install
#  if [ $? -ne 0 ]; then
#    echo "failed."
#    exit 1
#  else
#    echo "done."
#  fi
#fi
