#!/bin/bash

docker build -f=Dockerfile.goscanner --no-cache -t goscanner .

docker build -f=Dockerfile.download_upload -t goscanner-file-manager .
