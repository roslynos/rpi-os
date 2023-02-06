#!/bin/bash

# Abort script if any command returns error
set -e

ssh-keygen -f "$HOME/.ssh/known_hosts" -R "maui"
cat ~/.ssh/id_rsa.pub | ssh kai@maui 'mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys'
ssh kai@maui