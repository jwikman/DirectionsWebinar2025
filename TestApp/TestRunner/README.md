# Test Runner Infrastructure - Implementation Summary

## Overview
The Library TestApp includes complete test runner infrastructure for OData-based test execution via the BC on Linux workflow.

## Created Files

All files created in `TestApp/TestRunner/`:

1. **TestRunnerRequest.Table.al**
   - Table 70480 "LIB Test Runner Request"
   - Tracks test execution requests with status tracking

2. **TestRunnerRequestsAPI.Page.al**
   - Page 70480 "LIB Test Runner Requests" (API)
   - Endpoint: `/api/custom/automation/v1.0/codeunitRunRequests`
   - Service-enabled `RunCodeunit()` action

3. **TestLog.Table.al**
   - Table 70481 "LIB Test Log"
   - Auto-incrementing log entries with test results

4. **TestLogEntriesAPI.Page.al**
   - Page 70481 "LIB Test Log Entries API"
   - Endpoint: `/api/custom/automation/v1.0/logEntries`

5. **TestRunner.Codeunit.al**
   - Codeunit 70480 "LIB Test Runner"
   - Subtype = TestRunner
   - Implements `OnAfterTestRun` trigger for logging

## Object ID Mapping

| Original (PPC) | The Library | Object Type |
|---------------|-------------|-------------|
| Table 50003 | Table 70480 | Test Runner Request |
| Page 50002 | Page 70480 | Test Runner Requests API |
| Table 50002 | Table 70481 | Test Log |
| Page 50003 | Page 70481 | Test Log Entries API |
| Codeunit 50003 | Codeunit 70480 | Test Runner |

All IDs are within The Library TestApp range (70450-70499).

## How It Works

1. **Request Creation**: POST to `/api/custom/automation/v1.0/codeunitRunRequests` with `CodeunitId`
2. **Execution**: POST to `.../runCodeunit` action triggers test execution
3. **Status Polling**: GET from same endpoint to check status (Pending → Running → Finished/Error)
4. **Log Retrieval**: GET from `/api/custom/automation/v1.0/logEntries` to retrieve test results

## Integration with Workflow

The GitHub Actions workflow (`.github/workflows/build-linux.yml`) uses `scripts/run-tests-odata.ps1` which:

- Creates a test execution request via the API
- Triggers execution of codeunit 70451 "LIB Library Author Tests"
- Polls for completion (max 300 seconds)
- Retrieves and displays test logs
- Exits with appropriate status code

## Next Steps

To run all test codeunits:

1. Update workflow to call `run-tests-odata.ps1` multiple times:
   ```yaml
   - CodeunitId 70451  # Library Author Tests
   - CodeunitId 70452  # Library Book Tests
   - CodeunitId 70453  # Library Book Loan Tests
   ```

2. Or modify the test runner to support batch execution via `RunMultipleCodeunits("70451,70452,70453")`

## Source

Adapted from:
- Repository: https://github.com/StefanMaron/PipelinePerformanceComparison
- Directory: `src/testrunner/`
- Files: `runnertable.al`, `Log.al`, `LogAPI.al`, `cu50199.al`

## Verification

To verify the implementation:

1. Compile both App and TestApp
2. Publish to BC container
3. Run the workflow or execute manually:
   ```powershell
   pwsh ./scripts/run-tests-odata.ps1 -CodeunitId 70451
   ```

Expected result: Test executes successfully, logs are captured and displayed.
