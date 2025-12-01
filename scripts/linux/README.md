# Linux Build Scripts for Business Central

This folder contains bash scripts used by the GitHub Actions Linux build workflow for The Library app.

## Overview

The scripts follow the BCDevOnLinux pattern and enable full AL compilation, BC container deployment, and test execution on Linux/Ubuntu environments using Wine.

## Scripts

### `setup-dotnet-and-al.sh`

**Purpose:** Install .NET 8.0 SDK and AL Language development tools

**Usage:**
```bash
./setup-dotnet-and-al.sh <AL_VERSION> [BUILD_START_EPOCH]
```

**Parameters:**
- `AL_VERSION`: Version of Microsoft.Dynamics.BusinessCentral.Development.Tools.Linux (default: 17.0.28.6483-beta)
- `BUILD_START_EPOCH`: Optional epoch timestamp for accurate duration tracking

**Environment Variables Set:**
- `SETUP_DURATION`: Time taken for setup in seconds

---

### `download-bc-symbols.sh`

**Purpose:** Download Business Central symbol packages from Microsoft NuGet feeds

**Usage:**
```bash
./download-bc-symbols.sh <BC_VERSION> <PLATFORM_VERSION>
```

**Parameters:**
- `BC_VERSION`: Business Central version (default: 27.1.41698.41776)
- `PLATFORM_VERSION`: Platform version (default: 27.0.41766)

**Downloads:**
- Microsoft.SystemApplication
- Microsoft.BaseApplication
- Microsoft.Application.symbols
- Microsoft.BusinessFoundation
- Microsoft.Platform (System dependency)
- Microsoft.Any.symbols (test dependency)
- Microsoft.LibraryAssert.symbols (test dependency)
- Microsoft.TestRunner.symbols (test dependency)
- Microsoft.LibraryVariableStorage.symbols (test dependency)

**Environment Variables Set:**
- `SYSTEM_DOWNLOAD_DURATION`: Time taken for downloads and extraction
- `SYSTEM_EXTRACT_DURATION`: Always 0 (included for compatibility)

**Output:**
- Extracts .app files to `.alpackages/` directory

---

### `compile-al-apps.sh`

**Purpose:** Compile Main App and Test App using AL compiler

**Usage:**
```bash
./compile-al-apps.sh
```

**Process:**
1. Compiles Main App (`./App`)
2. Copies compiled Main App to `.alpackages/`
3. Compiles Test App (`./TestApp`)
4. Analyzes compiled apps (file sizes, counts)

**Environment Variables Set:**
- `COMPILE_DURATION`: Main app compilation time in seconds
- `TEST_COMPILE_DURATION`: Test app compilation time in seconds
- `APP_COUNT`: Number of compiled main apps
- `TOTAL_APP_SIZE_KB`: Total size of main apps in KB
- `TEST_APP_COUNT`: Number of compiled test apps
- `TOTAL_TEST_SIZE_KB`: Total size of test apps in KB
- `POST_COMPILE_ANALYSIS_DURATION`: Analysis time in seconds

---

### `setup-bc-container.sh`

**Purpose:** Setup Business Central container using BCDevOnLinux

**Usage:**
```bash
./setup-bc-container.sh <BCDEV_REPO> <BCDEV_BRANCH>
```

**Parameters:**
- `BCDEV_REPO`: BCDevOnLinux repository URL (default: https://github.com/StefanMaron/BCDevOnLinux.git)
- `BCDEV_BRANCH`: Branch to clone (default: main)

**Process:**
1. Verifies Docker installation
2. Clones BCDevOnLinux repository to `bcdev-temp/`
3. Pulls BC Wine base image (`stefanmaronbc/bc-wine-base:latest`)
4. Builds BC container using docker compose

**Environment Variables Set:**
- `DOCKER_SETUP_DURATION`: Docker verification time
- `BCDEV_CLONE_DURATION`: Repository clone time
- `BASE_IMAGE_PULL_DURATION`: Base image pull time
- `CONTAINER_BUILD_START`: Container build start timestamp
- `CONTAINER_BUILD_DURATION`: Container build time

---

### `start-bc-container.sh`

**Purpose:** Start BC container and wait for healthy status

**Usage:**
```bash
./start-bc-container.sh [MAX_WAIT_SECONDS]
```

**Parameters:**
- `MAX_WAIT_SECONDS`: Maximum wait time for container health (default: 1200 = 20 minutes)

**Process:**
1. Starts container using `docker compose up -d` in `bcdev-temp/`
2. Monitors container health status every 10 seconds
3. Prints logs if container becomes unhealthy
4. Exits with error if container doesn't become healthy within timeout

**Environment Variables Set:**
- `CONTAINER_START_DURATION`: Time taken for container to become healthy

**Health Monitoring:**
- Checks container health status every 10 seconds
- Logs status changes (starting → healthy or starting → unhealthy)
- Prints container logs on failure

---

### `publish-apps-to-container.sh`

**Purpose:** Publish AL apps to BC container via REST API

**Usage:**
```bash
./publish-apps-to-container.sh [BASE_URL] [USERNAME] [PASSWORD]
```

**Parameters:**
- `BASE_URL`: BC container base URL (default: http://localhost:7049)
- `USERNAME`: Authentication username (default: admin)
- `PASSWORD`: Authentication password (default: Admin123!)

**Process:**
1. Finds and publishes Main App to container
2. Finds and publishes Test App to container (excludes .dep.app files)
3. Uses BC dev/apps API endpoint with schema synchronization

**Environment Variables Set:**
- `PUBLISH_DURATION`: Main app publishing time
- `TEST_PUBLISH_DURATION`: Test app publishing time

**API Endpoint:**
```
POST {BASE_URL}/BC/dev/apps?tenant=default&SchemaUpdateMode=synchronize&DependencyPublishingOption=default
```

---

## Script Permissions

All scripts require execute permissions. The GitHub Actions workflow sets these automatically:

```bash
chmod +x ./scripts/linux/*.sh
```

## Error Handling

All scripts use `set -e` for immediate exit on errors and provide detailed error messages for troubleshooting.

## Environment Variables

Scripts set environment variables for duration tracking that are used by the workflow's performance summary step. The workflow prints a comprehensive timing breakdown at the end.

## Integration with GitHub Actions

These scripts are called by `.github/workflows/build-linux.yml`. The workflow:
1. Sets environment variables (AL_VERSION, BC_VERSION, etc.)
2. Passes these as arguments to the scripts
3. Tracks durations and metrics
4. Displays comprehensive performance summary

## Dependencies

- **bash**: All scripts are bash-based
- **bc**: Used for floating-point calculations
- **curl**: For downloading NuGet packages
- **unzip**: For extracting .nupkg files
- **docker** & **docker compose**: For BC container management
- **al compiler**: AL Language development tools (installed by setup script)
- **git**: For cloning BCDevOnLinux repository

## References

- [BCDevOnLinux](https://github.com/StefanMaron/BCDevOnLinux) - Wine-based BC Server on Linux
- [Microsoft BC Development Tools](https://www.nuget.org/packages/Microsoft.Dynamics.BusinessCentral.Development.Tools.Linux)
- [Business Central Symbol Packages](https://dynamicssmb2.visualstudio.com/571e802d-b44b-45fc-bd41-4cfddec73b44/_packaging)
