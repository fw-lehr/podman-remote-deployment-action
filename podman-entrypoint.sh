#!/bin/sh
set -eu

PATH_TO_PODMAN_COMPOSE="/usr/lib/python3/dist-packages/podman_compose.py"
sed 's/cmd_ls = \[self.podman_path, \*podman_args, cmd\] + xargs + cmd_args/cmd_ls = \[self.podman_path, \*xargs, \*podman_args, cmd\] + cmd_args/' $PATH_TO_PODMAN_COMPOSE > ./podman-compose.py
chmod u+x ./podman-compose.py

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

if [ -z "$INPUT_STACK_FILE_NAME" ]; then
  INPUT_STACK_FILE_NAME=docker-compose.yml
fi

if [ -z "$INPUT_SSH_PORT" ]; then
  INPUT_SSH_PORT=22
fi

CONTAINER_SSHKEY=~/.ssh/id_rsa

echo "Saving SSH key in ${CONTAINER_SSHKEY}"
# register the private key with the agent.
mkdir -p ~/.ssh
printf '%s\n' "$INPUT_SSH_PRIVATE_KEY" > $CONTAINER_SSHKEY
chmod 600 $CONTAINER_SSHKEY
eval $(ssh-agent)
ssh-add $CONTAINER_SSHKEY

STACK_FILE=${INPUT_STACK_FILE_NAME}
CONTAINER_HOST="ssh://$INPUT_REMOTE_CONTAINER_HOST:$INPUT_SSH_PORT$INPUT_REMOTE_SOCKET_PATH"
DEPLOYMENT_COMMAND="./podman-compose.py --podman-args=\"--connection vps\" -f $STACK_FILE"

echo "Add ${CONTAINER_HOST} to connections ... "
podman system connection add --identity "$CONTAINER_SSHKEY" vps "$CONTAINER_HOST"

if  [ -n "$INPUT_DOCKER_LOGIN_PASSWORD" ] || [ -n "$INPUT_DOCKER_LOGIN_USER" ] || [ -n "$INPUT_DOCKER_LOGIN_REGISTRY" ]; then
  echo "Command: podman --debug login -u ${INPUT_DOCKER_LOGIN_USER} -p $INPUT_DOCKER_LOGIN_PASSWORD $INPUT_DOCKER_LOGIN_REGISTRY"
  podman --debug --connection vps login -u "$INPUT_DOCKER_LOGIN_USER" -p "$INPUT_DOCKER_LOGIN_PASSWORD" "$INPUT_DOCKER_LOGIN_REGISTRY"
fi

echo "Command: ${DEPLOYMENT_COMMAND} ${INPUT_ARGS} executed at ${CONTAINER_HOST}"
eval "$DEPLOYMENT_COMMAND $INPUT_ARGS"
