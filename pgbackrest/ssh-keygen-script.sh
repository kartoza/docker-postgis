#!/bin/bash

if [ ! -f /shared-ssh/id_rsa ]; then
    ssh-keygen -t rsa -b 4096 -f /shared-ssh/id_rsa -N ''
    echo "SSH key generated"
else
    echo "SSH key already exists"
fi
