# AL Test Runner for Business Central

This directory contains PowerShell scripts for running AL tests in Business Central environments.

## Scripts

### Run-ALTests.ps1
Cross-platform PowerShell script that uses the Business Central Web Client framework (Microsoft.Dynamics.Framework.UI.Client.dll) to run AL tests.

**Requirements:**
- Business Central WebClient must be accessible and configured
- Requires IIS (Windows) or a web server like nginx (Linux) to serve the WebClient files
- Works with traditional Windows BC installations

**Usage:**
```powershell
$cred = Get-Credential
.\Run-ALTests.ps1 -ServiceUrl "http://localhost:7048/BC" -Credential $cred -TestSuite "DEFAULT"
```

### Test-GitHubActions.ps1
Test script specifically designed for GitHub Actions environments that validates the Run-ALTests.ps1 script.

**Current Status:**
- ✓ Successfully detects WebClient availability
- ✓ Provides clear error messages when WebClient is not configured
- ✗ Cannot run tests in Docker/Wine-based BC environments without WebClient

**Why it doesn't work in the current Docker setup:**
The Test-GitHubActions.ps1 script requires the Business Central WebClient endpoint (`/BC/WebClient/cs`) to be accessible. This endpoint is used by the Microsoft.Dynamics.Framework.UI.Client library to interact with BC's test framework.

In the current Docker/Wine-based BC environment:
1. BC Server is running and healthy ✓
2. WebClient files exist in `/home/bcartifacts/WebClient/` ✓
3. No web server (nginx/IIS) is configured to serve the WebClient ✗
4. The WebClient endpoint `/BC/WebClient/cs` is not accessible ✗

### Alternatives for Docker/Wine Environments

For BC environments running in Docker with Wine (like the current setup), you have several options:

1. **Use OData-based testing** (Recommended for CI/CD):
   ```powershell
   pwsh .github/scripts/run-tests-odata.ps1 -BaseUrl "http://localhost:7048/BC"
   ```

2. **Configure nginx to serve the WebClient**:
   - Add nginx service to docker-compose.yml
   - Configure nginx to serve files from `/home/bcartifacts/WebClient/PFiles/Microsoft Dynamics NAV/*/Web Client/WebPublish`
   - Map nginx to host port 80
   - This would enable Test-GitHubActions.ps1 to work

3. **Use a Windows-based BC environment**:
   - Traditional BC installation on Windows with IIS
   - BcContainerHelper with Windows containers
   - These environments have WebClient configured by default

## Architecture

### WebClient-based Testing (Run-ALTests.ps1)
```
Test Script → UI Client DLL → HTTP → WebClient (IIS/nginx) → BC Server
```

### OData-based Testing (run-tests-odata.ps1)
```
Test Script → HTTP/OData API → BC Server
```

## Technical Details

### How the WebClient Check Works
The Test-GitHubActions.ps1 script now includes a pre-flight check:

1. Attempts to access `$serviceUrl/WebClient` with a HEAD request (5 second timeout)
2. If successful: Proceeds with test execution
3. If fails: Displays error message with clear solutions

### URL Processing
The Microsoft.Dynamics.Framework.UI.Client library automatically appends `/WebClient/cs` to the base URL:
- Input: `http://localhost/BC`
- Processed: `http://localhost/BC/WebClient/cs`

### Port Configuration
The docker-compose.yml maps host port 80 to container port 7048:
```yaml
ports:
  - "80:7048"  # BC Web Client/OData (map host 80 to container 7048)
```

This allows accessing BC on `http://localhost/BC` instead of `http://localhost:7048/BC`.

## Summary

The Test-GitHubActions.ps1 script has been successfully debugged and enhanced:

✓ **Fixed Issues:**
- Corrected admin password (admin123! → Admin123!)
- Updated service URL (removed /WebClient?tenant=default)
- Added port 80 mapping in docker-compose.yml
- Added WebClient availability check
- Added clear error messaging with solutions

✓ **Current Status:**
- Script correctly identifies that WebClient is not available
- Provides actionable guidance for users
- Gracefully exits with informative error messages

❌ **Limitation:**
- Cannot execute tests without WebClient configured
- This is an architectural limitation, not a bug in the script

**Recommendation:** For CI/CD pipelines using Docker/Wine-based BC environments, use the OData-based test runner (`run-tests-odata.ps1`) instead, which doesn't require WebClient.
