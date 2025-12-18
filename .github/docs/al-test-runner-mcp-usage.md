# AL Test Runner MCP Server Usage Guide

This document explains how to use the al-test-runner MCP server to discover and run AL tests in this Business Central project.

## Overview

The al-test-runner MCP server provides three main tools for test automation:
1. `discover_al_tests` - Scans AL workspace for test codeunits and methods
2. `run_al_tests` - Executes tests against Business Central containers
3. `get_test_configuration` - Retrieves test configuration from .altestrunner.json and app.json

## Configuration

### Test Configuration File
Location: `TestApp/.altestrunner.json`

```json
{
    "containerName": "bcserver",
    "userName": "admin",
    "password": "Admin123!",
    "companyName": "CRONUS International Ltd."
}
```

### Test App Configuration
Location: `TestApp/app.json`

The test app includes the required dependencies:
- Library Assert (Microsoft)
- Test Runner (Microsoft)
- Any (Microsoft)
- Library Variable Storage (Microsoft)

## Test Inventory

This project contains 4 test codeunits with 22 test methods total:

### 1. LibraryMemberTests (Codeunit 70450) - 4 tests
- TestCreateLibraryMember
- TestLibraryMemberEmailValidation
- TestLibraryMemberInvalidEmail
- TestLibraryMemberMembershipTypes

### 2. LibraryAuthorTests (Codeunit 70451) - 5 tests
- TestCreateAuthor
- TestAuthorISNIValidation
- TestAuthorInvalidISNI
- TestAuthorORCIDValidation
- TestAuthorInvalidORCID

### 3. LibraryBookTests (Codeunit 70452) - 7 tests
- TestCreateBook
- TestBookISBNValidation
- TestBookInvalidISBN
- TestBookPublicationYearValidation
- TestBookInvalidPublicationYear
- TestBookQuantityValidation
- TestBookNegativeQuantity

### 4. LibraryBookLoanTests (Codeunit 70453) - 6 tests
- TestCreateBookLoan
- TestBookLoanExpectedReturnDateValidation
- TestBookLoanInvalidExpectedReturnDate
- TestBookLoanCannotDeletePosted
- TestBookLoanPostRequiresMember
- TestBookLoanPostRequiresLines

## Using al-test-runner MCP Server

### Step 1: Get Test Configuration

```typescript
// Retrieve configuration from .altestrunner.json and app.json
const config = await get_test_configuration({
  workspacePath: "/home/runner/work/TheLibrary/TheLibrary/TestApp"
});
```

### Step 2: Discover Tests

```typescript
// Scan the AL workspace for all test codeunits and methods
const tests = await discover_al_tests({
  workspacePath: "/home/runner/work/TheLibrary/TheLibrary/TestApp"
});

// Actual output from this repository:
// {
//   "success": true,
//   "testCodeunitsFound": 4,
//   "totalTestMethods": 22,
//   "testCodeunits": [
//     {
//       "id": 70450,
//       "name": "LIB Library Member Tests",
//       "methods": [
//         {"name": "TestCreateLibraryMember", "lineNumber": 16},
//         {"name": "TestLibraryMemberEmailValidation", "lineNumber": 38},
//         {"name": "TestLibraryMemberInvalidEmail", "lineNumber": 55},
//         {"name": "TestLibraryMemberMembershipTypes", "lineNumber": 71}
//       ]
//     }
//     // ... 3 more codeunits (70451, 70452, 70453)
//   ]
// }
```

### Step 3: Run All Tests

```typescript
// Execute all discovered tests against the BC container
const results = await run_al_tests({
  workspacePath: "/home/runner/work/TheLibrary/TheLibrary/TestApp",
  containerName: "localhost",  // Use localhost for local containers
  userName: "admin",
  password: "Admin123!",
  companyName: "CRONUS International Ltd."
});

// Actual output from this repository (December 15, 2025):
// {
//   "success": true,
//   "exitCode": 0,
//   "passedTests": 22,
//   "failedTests": 0
// }
// ✅ All 22 tests passed successfully!
// See test-execution-results.md for detailed results
```

### ✅ Verified Execution

The al-test-runner MCP server has been successfully tested with this repository:
- **Date**: December 15, 2025
- **Result**: All 22 tests passed ✅
- **Pass Rate**: 100%
- **Details**: See [test-execution-results.md](./test-execution-results.md) for full execution report

## Integration with GitHub Actions

The MCP server can be integrated into CI/CD workflows:

```yaml
- name: Run AL Tests via MCP
  run: |
    # The al-test-runner MCP server is configured in repository settings
    # and automatically available in the Copilot environment
    npx -y @al-test-runner/mcp-server
```

## Alternative: PowerShell Test Execution

For non-MCP environments, use the PowerShell script:

```powershell
./.github/scripts/run-tests-odata.ps1 `
  -BaseUrl "http://localhost:7048/BC" `
  -Tenant "default" `
  -Username "admin" `
  -CodeunitId 70450 `  # Run specific test codeunit
  -MaxWaitSeconds 300
```

## Prerequisites

1. **Running BC Container**: Ensure the Business Central Docker container is running and healthy
2. **Compiled Apps**: Both main app and test app must be compiled
3. **Published Apps**: Apps must be published to the container
4. **Test Dependencies**: Test app must include all required Microsoft test libraries

## Verification

To verify the test infrastructure is ready:

```bash
# Check container status
docker ps --filter "name=bcserver"

# Verify apps are compiled
ls -la App/*.app TestApp/*.app

# Test API connectivity
curl http://localhost:7048/BC/api/v2.0/companies
```

## Troubleshooting

### MCP Tools Not Available
If the al-test-runner MCP tools are not accessible:
1. Verify MCP server configuration in repository settings
2. Check that the workspace file path is correct
3. Ensure the BC container is running and accessible
4. Use the PowerShell fallback script for test execution

### Test Execution Failures
If tests fail to execute:
1. Check container logs: `docker logs bcdev-temp-bc-1`
2. Verify apps are published: Check API /api/v2.0/extensions
3. Validate test configuration in .altestrunner.json
4. Ensure company name matches the container company

## References

- [al-test-runner MCP Server](https://www.npmjs.com/package/@al-test-runner/mcp-server)
- [MCP Servers Configuration](./../instructions/mcp-servers.instructions.md)
- [Business Central Test Runner Documentation](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-testing-application)
