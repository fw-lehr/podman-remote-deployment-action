#!/bin/sh
set -eu

if [ -z "$INPUT_REMOTE_DOCKER_HOST" ]; then
    echo "Input remote_docker_host is required!"
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

STACK_FILE=${INPUT_STACK_FILE_NAME}
CONTAINER_HOST="ssh://$INPUT_REMOTE_DOCKER_HOST:$INPUT_SSH_PORT$INPUT_REMOTE_SOCKET_PATH"

DEPLOYMENT_COMMAND="podman compose -f $STACK_FILE"

CONTAINER_SSHKEY=~/.ssh/id_rsa

echo "Saving SSH key in ${CONTAINER_SSHKEY}"
# register the private key with the agent.
mkdir -p ~/.ssh
printf '%s\n' "$INPUT_SSH_PRIVATE_KEY" > $CONTAINER_SSHKEY
chmod 600 $CONTAINER_SSHKEY
eval $(ssh-agent)
ssh-add $CONTAINER_SSHKEY


if  [ -n "$INPUT_DOCKER_LOGIN_PASSWORD" ] || [ -n "$INPUT_DOCKER_LOGIN_USER" ] || [ -n "$INPUT_DOCKER_LOGIN_REGISTRY" ]; then
  echo "Connecting to $INPUT_REMOTE_DOCKER_HOST... Command: podman login"
  podman login -u "$INPUT_DOCKER_LOGIN_USER" -p "$INPUT_DOCKER_LOGIN_PASSWORD" "$INPUT_DOCKER_LOGIN_REGISTRY"
fi

echo "Command: ${DEPLOYMENT_COMMAND} ${INPUT_ARGS} executed at ${$CONTAINER_HOST}"
${DEPLOYMENT_COMMAND} ${INPUT_ARGS}
