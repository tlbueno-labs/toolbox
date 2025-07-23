#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status.
# Exit if any command in a pipeline fails.
set -e -o pipefail

# --- Default values (will be overridden by command-line arguments) ---
IMAGE_NAME=""
URL_LIST=()
DEBUG_MODE=false # New variable for debug flag
VALIDATION_CMDS=() # New variable for validation commands

# --- Function to display help message ---
show_help() {
    echo "Usage: $0 --image <container_image> --urls <url1,url2,...> [--debug] [--validation-cmds <cmd1,cmd2,...>]"
    echo ""
    echo "Arguments:"
    echo "  --image <container_image>        : The Podman image to use (e.g., fedora, quay.io/centos/centos:stream10)."
    echo "  --urls <url1,url2,...>           : A comma-separated list of RPM package URLs to validate."
    echo "  --debug                          : Enable debug mode (set -x) for verbose output."
    echo "  --validation-cmds <cmd1,cmd2,...>: Comma-separated list of commands to run inside the container after validation."
    echo ""
    echo "Example:"
    echo "  $0 --image quay.io/centos/centos:stream10 --urls https://example.com/package1.rpm --debug --validation-cmds \"ls,/bin/true\""
    exit 0
}

# --- Argument Parsing ---
# Loop through arguments until none left
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --image)
            # Check if an argument is provided for --image and it's not another option
            if [[ -n "$2" && "$2" != --* ]]; then
                IMAGE_NAME="$2"
                shift # Consume the value
            else
                echo "Error: --image requires a container image name." >&2
                show_help
            fi
            ;;
        --urls)
            # Check if an argument is provided for --urls and it's not another option
            if [[ -n "$2" && "$2" != --* ]]; then
                # Use IFS to split the comma-separated string into an array
                IFS=',' read -r -a URL_LIST <<< "$2"
                shift # Consume the value
            else
                echo "Error: --urls requires a comma-separated list of URLs." >&2
                show_help
            fi
            ;;
        --debug)
            DEBUG_MODE=true # Set debug mode flag
            ;;
        --validation-cmds)
            # Check if an argument is provided for --validation-cmds and it's not another option
            if [[ -n "$2" && "$2" != --* ]]; then
                IFS=',' read -r -a VALIDATION_CMDS <<< "$2"
                shift # Consume the value
            else
                echo "Error: --validation-cmds requires a comma-separated list of commands." >&2
                show_help
            fi
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Unknown option: $1" >&2
            show_help
            ;;
    esac
    shift # Consume the current option (e.g., --image, --urls, or --debug)
done

# --- Activate Debug Mode if requested ---
if ${DEBUG_MODE}; then
    echo "Debug mode enabled (set -x)."
    set -x
fi

# --- Validate Required Arguments ---
if [[ -z "$IMAGE_NAME" ]]; then
    echo "Error: --image is a mandatory argument." >&2
    show_help
fi

if [[ ${#URL_LIST[@]} -eq 0 ]]; then
    echo "Error: --urls is a mandatory argument." >&2
    show_help
fi

# --- Main Logic: Execute the Podman command with the inner script ---
echo "--- Validating RPM packages using image: ${IMAGE_NAME} ---"
echo -e '\n'

# Pass the number of URLs and debug mode as environment variables to the container
NUM_URLS="${#URL_LIST[@]}"
cat << 'INNER_SCRIPT_EOF' | podman run --rm -i -e DEBUG_MODE="${DEBUG_MODE}" "${IMAGE_NAME}" bash -s "${URL_LIST[@]}" "${VALIDATION_CMDS[@]}" "${NUM_URLS}"
# Everything between 'INNER_SCRIPT_EOF' and 'INNER_SCRIPT_EOF' will be executed inside the container.

# Enable debug mode inside the container if requested
if [[ "${DEBUG_MODE}" == "true" ]]; then
    echo "Inner script: Debug mode enabled (set -x)."
    set -x
fi

# Get NUM_URLS from the last positional parameter
NUM_URLS="${@: -1}"
ARGC=$#
packages_url=()
validation_cmds=()

# Collect URLs
for ((i=1; i<=NUM_URLS; i++)); do
    packages_url+=("${!i}")
done

# Collect validation commands (if any)
for ((i=NUM_URLS+1; i<ARGC; i++)); do
    validation_cmds+=("${!i}")
done

echo "--- OS Information ---"
cat /etc/os-release
echo -e '\n'

echo "--- Packages URLs ---"
for package_url in "${packages_url[@]}"; do
    echo " - $package_url"
done
echo -e '\n'

for package_url in "${packages_url[@]}"; do
    echo "--- Validating package from URL: $package_url ---"

    echo "--- Parsing package name from URL... ---"
    package_name=$(basename "$package_url")
    package_name="${package_name%.rpm}"
    echo "--- Extracted package name: $package_name ---"
    echo -e '\n'

    echo "--- Verifying if package $package_name is NOT installed ---"
    if rpm -q "$package_name" &>/dev/null; then
        echo "--- Package $package_name is installed and supposed to not be installed ---"
        exit 1
    else
        echo "--- Package $package_name is NOT installed ---"
    fi
    echo -e '\n'

    echo "--- Installing package: $package_url ---"
    dnf install --quiet --assumeyes --setopt=sslverify=false "$package_url"
    echo -e '\n'

    echo "--- Verifying if package $package_name is installed ---"
    if rpm -q "$package_name" &>/dev/null; then
        echo "--- Package $package_name is installed ---"
    else
        echo "--- Package $package_name is NOT installed and supposed to be installed ---"
        exit 1
    fi
    echo -e '\n'

    echo "--- Listing files for package: $package_name ---"
    rpm -ql "$package_name"
    echo -e '\n\n'
done

# --- Execute validation commands if any ---
if [[ ${#validation_cmds[@]} -gt 0 ]]; then
    echo "--- Running validation commands ---"
    for cmd in "${validation_cmds[@]}"; do
        echo ">>> $cmd"
        eval "$cmd"
        echo -e '\n'
    done
fi
INNER_SCRIPT_EOF

echo "--- RPM package validation process completed ---"
