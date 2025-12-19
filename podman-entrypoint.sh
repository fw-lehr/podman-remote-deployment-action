#!/bin/sh
set -eu  # Exit on error and undefined variables

## This script configures SSH access to a remote Podman host and deploys containers using podman-compose.
## Before running this script, ensure that the remote Podman host is set up to accept SSH connections
## via podman's remote API over SSH. (see https://docs.podman.io/en/latest/markdown/podman-remote.1.html)
## In addition, the script performs a login to a container registry if the relevant parameters are provided.

## It uses the following parameters:
if [ -z "$INPUT_REMOTE_CONTAINER_HOST" ]; then
    echo "Input remote_container_host is required!"
    exit 1
fi

if [ -z "$INPUT_REMOTE_SOCKET_PATH" ]; then
  INPUT_REMOTE_SOCKET_PATH=/run/user/1000/podman/podman.sock
fi

if [ -z "$INPUT_SSH_PRIVATE_KEY" ]; then
    echo "Input ssh_private_key is required!"
    exit 1
fi

if [ -z "$INPUT_ARGS" ]; then
  echo "Input input_args is required!"
  exit 1
fi

if [ -z "$INPUT_COMPOSE_FILE_NAME" ]; then
  INPUT_COMPOSE_FILE_NAME=docker-compose.yml
fi

if [ -z "$INPUT_SSH_PORT" ]; then
  INPUT_SSH_PORT=22
fi

## For some reason, even the current (1.5.0) podman-compose package
## has a bug in handling the args that should be passed to the podman
## instances called by podman-compose
## See also https://github.com/containers/podman-compose/issues/707
## We patch it here.
PATH_TO_PODMAN_COMPOSE="/usr/lib/python3/dist-packages/podman_compose.py"
sed 's/cmd_ls = \[self.podman_path, \*podman_args, cmd\] + xargs + cmd_args/cmd_ls = \[self.podman_path, \*xargs, \*podman_args, cmd\] + cmd_args/' $PATH_TO_PODMAN_COMPOSE > ./podman-compose.py
chmod u+x ./podman-compose.py

## These podman args are necessary, because (for some reason), the 
## environment variable(s) are not passed to the called podman instances.
## Therefore, we have to create a connection named "vps" and use this 
## connection in the podman-compose calls.

# Filename where to save the SSH private key inside the container
CONTAINER_SSHKEY=~/.ssh/id_rsa
echo "Saving SSH key in ${CONTAINER_SSHKEY}"
# register the private key with the agent.
mkdir -p ~/.ssh
printf '%s\n' "$INPUT_SSH_PRIVATE_KEY" > $CONTAINER_SSHKEY
chmod 600 $CONTAINER_SSHKEY
eval $(ssh-agent)
ssh-add $CONTAINER_SSHKEY

## The final deployment command is constructed here
COMPOSE_FILE=${INPUT_COMPOSE_FILE_NAME}
CONTAINER_HOST="ssh://$INPUT_REMOTE_CONTAINER_HOST:$INPUT_SSH_PORT$INPUT_REMOTE_SOCKET_PATH"
DEPLOYMENT_COMMAND="./podman-compose.py --podman-args=\"--connection remote\" -f $COMPOSE_FILE"

## Add the remote host as a podman connection
echo "Add ${CONTAINER_HOST} to connections ... "
podman system connection add --identity "$CONTAINER_SSHKEY" remote "$CONTAINER_HOST"

## Perform login to container registry if parameters are provided
if  [ -n "$INPUT_DOCKER_LOGIN_PASSWORD" ] || [ -n "$INPUT_DOCKER_LOGIN_USER" ] || [ -n "$INPUT_DOCKER_LOGIN_REGISTRY" ]; then
  echo "Command: podman --debug login -u ${INPUT_DOCKER_LOGIN_USER} -p $INPUT_DOCKER_LOGIN_PASSWORD $INPUT_DOCKER_LOGIN_REGISTRY"
  podman --debug --connection remote login -u "$INPUT_DOCKER_LOGIN_USER" -p "$INPUT_DOCKER_LOGIN_PASSWORD" "$INPUT_DOCKER_LOGIN_REGISTRY"
fi

## Finally, execute the (remote) deployment command
echo "Command: ${DEPLOYMENT_COMMAND} ${INPUT_ARGS} executed at ${CONTAINER_HOST}"
eval "$DEPLOYMENT_COMMAND $INPUT_ARGS"
