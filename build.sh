#!/bin/bash

podman build -f=Dockerfile.goscanner --no-cache -t goscanner .

podman build -f=Dockerfile.download_upload -t goscanner-file-manager .
