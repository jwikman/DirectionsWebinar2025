#!/bin/bash
set -e

# Setup Business Central container using BCDevOnLinux
# Usage: ./setup-bc-container.sh <BCDEV_REPO> <BCDEV_BRANCH>

BCDEV_REPO="${1:-https://github.com/StefanMaron/BCDevOnLinux.git}"
BCDEV_BRANCH="${2:-main}"

echo "=== Setting up Business Central Container ==="

# Verify Docker is available
echo "Verifying Docker installation..."
DOCKER_SETUP_START=$(date +%s.%N)
docker --version
docker compose version
DOCKER_SETUP_END=$(date +%s.%N)
DOCKER_SETUP_DURATION=$(echo "$DOCKER_SETUP_END - $DOCKER_SETUP_START" | bc -l | sed 's/^\./0./')
echo "DOCKER_SETUP_DURATION=$DOCKER_SETUP_DURATION" >> "$GITHUB_ENV"
echo "Docker setup took: $DOCKER_SETUP_DURATION seconds"

# Clone BCDevOnLinux repository
echo "Cloning BCDevOnLinux repository..."
CLONE_START=$(date +%s.%N)
git clone --branch "$BCDEV_BRANCH" --depth 1 "$BCDEV_REPO" bcdev-temp
CLONE_END=$(date +%s.%N)
CLONE_DURATION=$(echo "$CLONE_END - $CLONE_START" | bc -l | sed 's/^\./0./')
echo "BCDEV_CLONE_DURATION=$CLONE_DURATION" >> "$GITHUB_ENV"
echo "BCDevOnLinux clone took: $CLONE_DURATION seconds"

# Pull BC Wine Base Image
echo "Pulling BC Wine base image..."
CONTAINER_BUILD_START=$(date +%s.%N)
echo "CONTAINER_BUILD_START=$CONTAINER_BUILD_START" >> "$GITHUB_ENV"

BASE_IMAGE_PULL_START=$(date +%s.%N)
docker pull stefanmaronbc/bc-wine-base:latest
BASE_IMAGE_PULL_END=$(date +%s.%N)
BASE_IMAGE_PULL_DURATION=$(echo "$BASE_IMAGE_PULL_END - $BASE_IMAGE_PULL_START" | bc -l | sed 's/^\./0./')
echo "BASE_IMAGE_PULL_DURATION=$BASE_IMAGE_PULL_DURATION" >> "$GITHUB_ENV"
echo "Base image pull took: $BASE_IMAGE_PULL_DURATION seconds"

# Build BC Container with Docker Compose
echo "Building Business Central container..."
cd bcdev-temp
docker compose build
CONTAINER_BUILD_END=$(date +%s.%N)
CONTAINER_BUILD_DURATION=$(echo "$CONTAINER_BUILD_END - $CONTAINER_BUILD_START" | bc -l | sed 's/^\./0./')
echo "CONTAINER_BUILD_DURATION=$CONTAINER_BUILD_DURATION" >> "$GITHUB_ENV"
echo "Container build took: $CONTAINER_BUILD_DURATION seconds"
cd ..
