# The Library - Test Summary

## Test Discovery Results

This document summarizes the automated test discovery performed on The Library AL project.

### Overview

- **Total Test Codeunits**: 4
- **Total Test Methods**: 22
- **Test Framework**: AL Test Tool (Business Central)
- **Dependencies**: Library Assert, Test Runner, Any, Library Variable Storage

## Test Codeunits

### 1. LIB Library Author Tests (Codeunit 70451)

**File**: `TestApp/src/LibraryAuthorTests.Codeunit.al`

**Test Methods** (5):

1. **TestCreateAuthor** (Line 16)
   - Verifies that a new author is created with an auto-assigned number from the number series

2. **TestAuthorISNIValidation** (Line 32)
   - Tests that valid ISNI (16 digits) is accepted

3. **TestAuthorInvalidISNI** (Line 49)
   - Validates that invalid ISNI (not 16 digits) throws an error

4. **TestAuthorORCIDValidation** (Line 65)
   - Tests that valid ORCID format is accepted

5. **TestAuthorInvalidORCID** (Line 82)
   - Validates that invalid ORCID format throws an error

### 2. LIB Library Book Loan Tests (Codeunit 70453)

**File**: `TestApp/src/LibraryBookLoanTests.Codeunit.al`

**Test Methods** (6):

1. **TestCreateBookLoan** (Line 16)
   - Verifies book loan creation with auto-assigned number, loan date, and open status

2. **TestBookLoanExpectedReturnDateValidation** (Line 38)
   - Tests that expected return date after loan date is accepted

3. **TestBookLoanInvalidExpectedReturnDate** (Line 55)
   - Validates that expected return date before loan date throws an error

4. **TestBookLoanCannotDeletePosted** (Line 71)
   - Ensures posted book loans cannot be deleted

5. **TestBookLoanPostRequiresMember** (Line 89)
   - Validates that posting requires a member to be assigned

6. **TestBookLoanPostRequiresLines** (Line 106)
   - Validates that posting requires at least one loan line

### 3. LIB Library Book Tests (Codeunit 70452)

**File**: `TestApp/src/LibraryBookTests.Codeunit.al`

**Test Methods** (7):

1. **TestCreateBook** (Line 16)
   - Verifies that a new book is created with an auto-assigned number

2. **TestBookISBNValidation** (Line 32)
   - Tests that valid ISBN format is accepted

3. **TestBookInvalidISBN** (Line 49)
   - Validates that ISBN with letters throws an error

4. **TestBookPublicationYearValidation** (Line 65)
   - Tests that valid publication year is accepted

5. **TestBookInvalidPublicationYear** (Line 82)
   - Validates that future publication year throws an error

6. **TestBookQuantityValidation** (Line 97)
   - Tests that valid quantity is accepted

7. **TestBookNegativeQuantity** (Line 114)
   - Validates that negative quantity throws an error

### 4. LIB Library Member Tests (Codeunit 70450)

**File**: `TestApp/src/LibraryMemberTests.Codeunit.al`

**Test Methods** (4):

1. **TestCreateLibraryMember** (Line 16)
   - Verifies member creation with auto-assigned number, member since date, and active status

2. **TestLibraryMemberEmailValidation** (Line 38)
   - Tests that valid email format is accepted

3. **TestLibraryMemberInvalidEmail** (Line 55)
   - Validates that invalid email format throws an error

4. **TestLibraryMemberMembershipTypes** (Line 71)
   - Tests all membership type enum values (Regular, Student, Senior)

## Test Configuration

### Test App Configuration

**File**: `TestApp/app.json`

- **App ID**: 2ef0bab6-32ad-443a-a354-5f12b2d80486
- **Name**: The Library Tester
- **Publisher**: Johannes Wikman
- **Version**: 1.0.0.0
- **Platform**: 27.0.0.0 (BC27)
- **Runtime**: 16.0

### AL Test Runner Configuration

**File**: `TestApp/.altestrunner.json`

```json
{
    "containerName": "bcserver",
    "userName": "admin",
    "password": "Admin123!",
    "companyName": "CRONUS International Ltd."
}
```

## Running Tests

### Prerequisites

1. Business Central container running (named `bcserver` or configured in `.altestrunner.json`)
2. Main app published to the container
3. Test app published to the container
4. AL Test Runner framework available

### Using GitHub Actions Workflow

The repository includes a comprehensive CI/CD workflow at `.github/workflows/copilot-setup-steps.yml` that:

1. Sets up .NET 8.0 and AL tools
2. Gets the latest BC artifact URL
3. Creates and starts a BC container
4. Downloads symbol packages for both Main and Test apps
5. Compiles both apps
6. Publishes apps to the container
7. Runs tests via OData API (Test Suite Codeunit 70454)

**To run tests via GitHub Actions:**

```bash
# Trigger the workflow manually
gh workflow run copilot-setup-steps.yml
```

### Using AL Test Runner MCP

When a BC container is running locally:

```javascript
// Discover all tests
al-test-runner-discover_al_tests({
    workspacePath: "/path/to/TheLibrary/TestApp"
})

// Run all tests
al-test-runner-run_al_tests({
    workspacePath: "/path/to/TheLibrary/TestApp",
    containerName: "bcserver",
    userName: "admin",
    password: "Admin123!"
})
```

### Using PowerShell Scripts

The repository includes PowerShell scripts for test execution:

```powershell
# Run tests via OData API
./.github/scripts/run-tests-odata.ps1 `
    -BaseUrl "http://localhost:7048/BC" `
    -Tenant "default" `
    -Username "admin" `
    -Password "Admin123!" `
    -CodeunitId 70454 `
    -MaxWaitSeconds 300
```

## Test Coverage

The test suite provides comprehensive coverage of the core library functionality:

- ✅ **Entity Creation**: Tests for all main entities (Author, Book, Member, Loan)
- ✅ **Validation Logic**: Field-level validation for business rules
- ✅ **Number Series**: Auto-assignment of record numbers
- ✅ **Business Rules**: Domain-specific constraints (dates, formats, quantities)
- ✅ **State Management**: Status transitions and posting logic
- ✅ **Error Handling**: Negative test cases for invalid inputs

## Test Suite Codeunit

**File**: `TestApp/src/TestSuite.Codeunit.al`

The repository includes a Test Suite codeunit (70454) that:
- Automatically creates a test suite named "LIB"
- Subscribes to the AL Test Tool page open event
- Auto-populates all test methods from the current app using `Test Suite Mgt.`

This enables running all tests through the standard AL Test Tool UI.

## Notes

- All tests use the `TestPermissions = Disabled` setting for simplified execution
- Tests use the `Library Assert` codeunit for assertions
- Tests use the `Any` codeunit for random test data generation
- Number series are created dynamically in test setup to avoid conflicts
- Tests follow the Given-When-Then pattern for readability

## Conclusion

The Library project has a well-structured test suite with 22 automated tests covering all major functionality. Tests are properly configured for execution in Business Central environments and can be run via multiple methods (AL Test Tool UI, OData API, AL Test Runner MCP, or GitHub Actions workflows).
