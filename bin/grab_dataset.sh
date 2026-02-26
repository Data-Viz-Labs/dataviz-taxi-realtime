#!/bin/bash

# Check if curl and unzip are available
command -v curl >/dev/null 2>&1 || { echo >&2 "I require curl but it's not installed. Aborting."; exit 1; }
command -v unzip >/dev/null 2>&1 || { echo >&2 "I require unzip but it's not installed. Aborting."; exit 1; }

# Download dataset from kaggle
# https://www.kaggle.com/datasets/crailtap/taxi-trajectory

curl -L -o ../data/archive.zip\
  https://www.kaggle.com/api/v1/datasets/download/crailtap/taxi-trajectory

mkdir -p ../data
cd ../data

unzip archive.zip
rm archive.zip
