#!/bin/bash

# Create the infrastructure directory if it doesn't exist
mkdir -p dep/infrastructure

# Navigate to the API project directory
cd ../../HireAPro.api/src/HireAPro.api

# Clean any existing publish
rm -rf ./publish

# Publish the application for Linux x64 (required for AWS Lambda)
dotnet publish -c Release -o ./publish --runtime linux-x64 --self-contained true

# Create a zip file of the published application
cd ./publish
zip -r ../../../../dep/infrastructure/HireAPro.api.zip ./*

echo "Application published and zipped successfully!" 