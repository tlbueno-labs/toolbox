# validate-rpm-package.sh

## Overview

`validate-rpm-package.sh` is a Bash script designed to automate the validation of RPM packages inside a container environment (using Podman). It downloads and installs specified RPMs, verifies their installation status, and optionally runs custom validation commands inside the container. This helps ensure package integrity and compatibility in a clean, reproducible OS environment.

## Features

- Runs in a disposable Podman container (e.g., CentOS Stream, Fedora, etc.)
- Validates that RPMs are not installed before installation
- Installs RPMs from provided URLs
- Verifies successful installation and lists package files
- Optionally runs custom validation commands after installation
- Supports debug mode for troubleshooting

## Usage

```bash
./validate-rpm-package.sh --image <container_image> --urls <url1,url2,...> [--debug] [--validation-cmds <cmd1,cmd2,...>]
```

### Arguments

- `--image <container_image>`  
  The Podman image to use (e.g., `fedora`, `quay.io/centos/centos:stream10`). **Required.**

- `--urls <url1,url2,...>`  
  Comma-separated list of RPM package URLs to validate. **Required.**

- `--debug`  
  Enable debug mode (`set -x`) for verbose output. **Optional.**

- `--validation-cmds <cmd1,cmd2,...>`  
  Comma-separated list of shell commands to run inside the container after RPM validation. **Optional.**

- `-h`, `--help`  
  Show usage information.

### Example

```bash
./validate-rpm-package.sh \
  --image quay.io/centos/centos:stream10 \
  --urls https://example.com/package1.rpm,https://example.com/package2.rpm \
  --debug \
  --validation-cmds "ls,/bin/true"
```

## How It Works

1. **Argument Parsing:**  
   The script parses command-line arguments for image, RPM URLs, debug mode, and optional validation commands.

2. **Container Execution:**  
   It launches a Podman container with the specified image and runs an inner Bash script.

3. **RPM Validation:**  
   - Checks that each RPM is not already installed.
   - Installs each RPM from the provided URLs.
   - Verifies installation and lists package files.

4. **Custom Validation:**  
   If provided, runs each custom command inside the container after RPM validation.

## Requirements

- Bash
- Podman
- Internet access to download RPMs

## Notes

- The script is intended for use in CI pipelines, package testing, or developer validation workflows.
- Only RPM URLs accessible from the container will work.
- Validation commands are run with `eval` inside the container.

## License

MIT
