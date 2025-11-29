# Test Execution Scripts

This directory contains scripts for executing AL tests via the OData API.

## OData Test Execution

### Overview

The `run-tests-odata.ps1` script executes AL test codeunits via the Business Central OData API using the **Codeunit Run Request** system.

This script was copied from the [PipelinePerformanceComparison](https://github.com/StefanMaron/PipelinePerformanceComparison) repository as part of the BC on Linux POC.

### Usage

#### Local Testing

```bash
# Execute test codeunit against local BC container
# Note: OData port is 7048, SOAP/web services port is 7049
pwsh ./scripts/run-tests-odata.ps1 \
  -BaseUrl "http://localhost:7048/BC" \
  -CodeunitId 50002
```

#### GitHub Actions (Linux Pipeline)

The script is integrated into the Linux pipeline at `.github/workflows/build-linux.yml`:

```yaml
- name: Run AL Tests in Container via OData
  run: |
    pwsh ./scripts/run-tests-odata.ps1 \
      -BaseUrl "http://localhost:7048/BC" \
      -Tenant "default" \
      -Username "admin" \
      -Password "Admin123!" \
      -CodeunitId 50002 \
      -MaxWaitSeconds 300
```

### Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `BaseUrl` | No | `http://localhost:7048/BC` | Base URL of BC instance (OData port) |
| `Tenant` | No | `default` | Tenant name |
| `Username` | No | `admin` | Authentication username |
| `Password` | No | `Admin123!` | Authentication password |
| `CodeunitId` | No | `50001` | Test codeunit ID to execute |
| `MaxWaitSeconds` | No | `300` | Maximum wait time for completion |

### Prerequisites

To use this script, your BC extension must include:

1. **Codeunit Run Request table** (table 50003) - for tracking execution state
2. **Codeunit Run Requests API** (page 50002) - OData endpoint for execution
3. **Test Runner API** (codeunit 50003) - handles codeunit execution
4. **Log Table** (table 50002) - stores execution logs
5. **Log Entries API** (page 50003) - OData endpoint for logs

These components are available in the [PipelinePerformanceComparison](https://github.com/StefanMaron/PipelinePerformanceComparison/tree/main/src/testrunner) repository.

### Exit Codes

- `0` - Test execution succeeded (Status = "Finished")
- `1` - Test execution failed (Status = "Error" or timeout)

## Future Enhancements

When converting from bash to PowerShell:

1. Replace bash scripts in the workflow with PowerShell equivalents
2. Use PowerShell cmdlets instead of shell commands (e.g., `Test-Path` instead of `[ -f ]`)
3. Leverage PowerShell's object-oriented features for better error handling
4. Consider creating PowerShell modules for reusable functions

## Related Documentation

- [BCDevOnLinux](https://github.com/StefanMaron/BCDevOnLinux) - BC Server on Linux using Wine
- [PipelinePerformanceComparison](https://github.com/StefanMaron/PipelinePerformanceComparison) - Source of this script
- [BcContainerHelper](https://github.com/microsoft/navcontainerhelper) - PowerShell module for BC containers
