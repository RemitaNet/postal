#!/bin/bash

# Save the starting directory
START_DIR=$(pwd)

# Ensure we return to the starting directory on exit
trap 'cd "$START_DIR"' EXIT

# Function to build and push Docker images
build_and_push_image() {
    local dockerfile="$1"
    local image_name="$2"
    local image_tag="registry.remita.net/systemspecs/remita-payment-services/technology/platform-engineering/core-platform/notification-service-v2/notification-service:postal-${DATE_WITH_TIME}"

    echo ">>> Building image: ${image_tag}"

    # Remove existing image if it exists
    if docker inspect "${image_tag}" >/dev/null 2>&1; then
        echo ">>> Removing existing image"
        docker rmi "${image_tag}" || true
    fi

    # Build the image
    echo ">>> Starting build process"
    docker build \
        -f "${dockerfile}" \
        --platform=linux/amd64 \
        --build-arg NODE_OPTIONS="--max-old-space-size=8192" \
        -t "${image_tag}" \
        --no-cache \
        .

    # Push the image
    echo ">>> Pushing image to registry"
    docker push "${image_tag}"

    echo ">>> Successfully built and pushed image: ${image_tag}"
}

# Get timestamp with milliseconds
DATE_WITH_TIME=$(date "+%Y%m%d.%H%M%S.%3N")

# Build and push the main Superset image
echo ">>> Building Apache Superset image"
if build_and_push_image "RemitaDockerfile" "apache-superset"; then
    echo ">>> First build succeeded. Proceeding to WebSocket build."
else
    echo ">>> First build failed. Exiting script."
    exit 1
fi

# Only proceed to build WebSocket if the first build succeeds
echo ">>> Building Apache Superset WebSocket image"
if cd ./superset-websocket; then
    build_and_push_image "Dockerfile" "apache-superset" "websocket-"
else
    echo ">>> Failed to enter WebSocket directory. Exiting script."
    exit 1
fi

# Return to the original directory (this is redundant due to trap but added for clarity)
cd "$START_DIR"

# Cleanup builder cache
echo ">>> Cleaning up builder cache"
docker builder prune -f

echo ">>> Done !!!"
