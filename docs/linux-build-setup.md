# Linux Build Workflow Setup - Summary

This document summarizes the files copied from the PipelinePerformanceComparison repository for the BC on Linux POC.

## Files Copied

### 1. Workflow File
**Source:** `https://github.com/StefanMaron/PipelinePerformanceComparison/blob/main/.github/workflows/build-linux.yml`
**Destination:** `.github/workflows/build-linux.yml`

**Modifications made for The Library app:**
- Changed compilation path from project root to `App` folder
- Updated `.alpackages` path to `App/.alpackages` and `TestApp/.alpackages`
- Modified app file search to look in `App` and `TestApp` folders
- Added TestApp compilation step
- Added TestApp publishing step (5-second delay between App and TestApp)
- **Enabled test execution** - runs codeunit 70451 "LIB Library Author Tests" via OData API
- Changed `AL` command to `al` (lowercase) for recent compiler versions

### 2. PowerShell Test Script
**Source:** `https://github.com/StefanMaron/PipelinePerformanceComparison/blob/main/scripts/run-tests-odata.ps1`
**Destination:** `scripts/run-tests-odata.ps1`

**No modifications** - copied as-is from the source repository.

### 3. Documentation
**Created:** `scripts/README.md`
**Purpose:** Documents how to use the test execution script and its prerequisites.

## Workflow Overview

The Linux build workflow (`build-linux.yml`) performs these steps:

1. **Setup** - Install .NET 8.0 and BC Development Tools for Linux
2. **Dependencies** - Download BC symbol packages (System, Base, Application) from NuGet
3. **Compilation** - Compile the AL extension using the AL compiler
4. **Docker Setup** - Clone BCDevOnLinux and prepare BC container
5. **Container Build** - Build BC container using Wine (via BCDevOnLinux v2)
6. **Container Start** - Start BC container and wait for healthy status
7. **Publishing** - Publish compiled app to BC container via API
8. **Testing** - Execute test codeunits via OData API (currently runs codeunit 70451)
9. **Metrics** - Collect comprehensive performance metrics in JSON format
10. **Artifacts** - Upload compiled apps and metrics

## Key Dependencies

### External Repositories
- **BCDevOnLinux** (`https://github.com/StefanMaron/BCDevOnLinux.git`, branch `v2`)
  - Provides Wine-based BC Server configuration
  - Docker Compose setup for BC on Linux
  - Base image: `stefanmaronbc/bc-wine-base:latest`

### BC Symbol Packages
- Microsoft.SystemApplication.US.symbols (v26.3.36158.36341)
- Microsoft.BaseApplication.US.symbols (v26.3.36158.36341)
- Microsoft.Application.US.symbols (v26.3.36158.36341)
- Microsoft.BusinessFoundation.US.symbols (v26.3.36158.36341)
- Microsoft.Platform.symbols (v26.0.38176)

Downloaded from: `https://dynamicssmb2.pkgs.visualstudio.com/...`

## Known Limitations

### Test Execution (Currently Active)
The test execution step is now enabled and runs:
- **Codeunit 70451** "LIB Library Author Tests"

Available test codeunits in TestApp:
- Codeunit 70451 "LIB Library Author Tests" (currently executed)
- Codeunit 70452 "LIB Library Book Tests" (not executed)
- Codeunit 70453 "LIB Library Book Loan Tests" (not executed)

To run additional test codeunits, update the `CodeunitId` parameter in the "Run AL Tests" step.

### Test Runner Infrastructure

**✓ COMPLETED**: The Library TestApp now includes the complete test runner infrastructure required by `run-tests-odata.ps1`. The following objects have been created in `TestApp/TestRunner/`:

**Test Runner Objects (ID Range 70480-70481):**

1. **Table 70480** "LIB Test Runner Request" (`TestRunnerRequest.Table.al`)
   - Tracks execution requests with status (Pending/Running/Finished/Error)
   - Stores codeunit ID, status, last result, and execution timestamp

2. **Page 70480** "LIB Test Runner Requests" (`TestRunnerRequestsAPI.Page.al`)
   - OData API endpoint: `/api/custom/automation/v1.0/codeunitRunRequests`
   - Exposes the execution request table via REST API
   - Provides `Microsoft.NAV.runCodeunit` action for triggering execution

3. **Table 70481** "LIB Test Log" (`TestLog.Table.al`)
   - Stores execution logs with test results
   - Captures codeunit ID, function name, success status, error messages, call stacks

4. **Page 70481** "LIB Test Log Entries API" (`TestLogEntriesAPI.Page.al`)
   - OData API endpoint: `/api/custom/automation/v1.0/logEntries`
   - Allows retrieval of execution logs via REST API

5. **Codeunit 70480** "LIB Test Runner" (`TestRunner.Codeunit.al`)
   - Test runner with `Subtype = TestRunner`
   - Executes test codeunits and captures results
   - Implements `OnAfterTestRun` trigger to log test execution details

**Source:**
- Adapted from: https://github.com/StefanMaron/PipelinePerformanceComparison/tree/main/src/testrunner
- Object IDs renumbered to The Library TestApp range (70480-70481)

### Platform Version
The workflow uses BC version **26.3** for symbol packages. Update `BC_VERSION` and `PLATFORM_VERSION` in the workflow if you need a different version.

## Running the Workflow

### Trigger the Workflow
1. Go to GitHub Actions in your repository
2. Select "Build Linux (Full Test)" workflow
3. Click "Run workflow" button
4. Select the branch to run on
5. Click "Run workflow"

### Expected Duration
Based on PipelinePerformanceComparison metrics:
- Setup: ~30-60 seconds
- Dependencies: ~30-90 seconds
- Compilation: ~10-30 seconds
- Container Build: ~2-5 minutes
- Container Start: ~5-10 minutes
- **Total: ~10-20 minutes** (varies by GitHub runner performance)

### Artifacts Generated
After workflow completion, download these artifacts:
- `linux-full-test-artifacts.zip` containing:
  - Compiled `.app` files (both App and TestApp)
  - `linux-full-test-metrics.json` - Performance metrics
  - `linux-full-test-raw-measurements.json` - Detailed timing breakdown

## Next Steps

### For POC (Proof of Concept)
1. ✅ Workflow file copied
2. ✅ Test script copied
3. ✅ Paths updated for The Library app structure (App and TestApp)
4. ✅ Test execution enabled with codeunit 70451
5. ✅ AL command updated to lowercase for recent versions
6. ⏭️ Run the workflow and verify compilation works
7. ⏭️ Check that both apps publish to BC container successfully
8. ⏭️ Verify test execution completes successfully

### For Full Implementation
1. ✅ Add test codeunits to The Library app (completed - TestApp exists)
2. ✅ **Test runner infrastructure created** (5 objects in TestApp/TestRunner/)
3. ✅ Object IDs renumbered to TestApp range (70480-70481)
4. ⏭️ Configure which test codeunits to run (currently only 70451)
5. ⏭️ Consider running all test codeunits (70451, 70452, 70453) in parallel or sequence
6. ⏭️ Convert remaining bash scripts to PowerShell (optional improvement)

### Converting to PowerShell
The current workflow uses bash scripts for Linux. To convert to PowerShell:

1. Replace bash date/time commands with PowerShell:
   ```powershell
   $startTime = Get-Date
   $duration = (Get-Date) - $startTime
   ```

2. Replace bash conditionals with PowerShell:
   ```powershell
   if (Test-Path $file) { ... }
   ```

3. Replace bash loops with PowerShell:
   ```powershell
   Get-ChildItem -Filter "*.app" | ForEach-Object { ... }
   ```

4. Use PowerShell's built-in JSON support:
   ```powershell
   $metrics | ConvertTo-Json | Out-File metrics.json
   ```

## Troubleshooting

### Compilation Fails
- Check that BC symbol packages downloaded successfully
- Verify BC version matches app.json platform version
- Check AL compiler output for specific errors

### Container Won't Start
- Check BCDevOnLinux repository is accessible
- Verify Docker is available on runner
- Check container logs in workflow output

### Publishing Fails
- Ensure container is healthy before publishing
- Verify API credentials (admin:Admin123!)
- Check app dependencies are available

## References

- [BCDevOnLinux Repository](https://github.com/StefanMaron/BCDevOnLinux)
- [PipelinePerformanceComparison Repository](https://github.com/StefanMaron/PipelinePerformanceComparison)
- [BC Development Tools for Linux](https://www.nuget.org/packages/Microsoft.Dynamics.BusinessCentral.Development.Tools.Linux)

---

**Created:** 2025-11-29
**Source:** PipelinePerformanceComparison repository
**Purpose:** BC on Linux POC for The Library app
