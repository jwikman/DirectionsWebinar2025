/// <summary>
/// Test Runner Request - State-tracked execution requests for the Test Runner API
///
/// This table stores execution requests with status tracking, providing a stateful
/// alternative to the stateless Test Runner API (codeunit 70480).
///
/// Purpose:
/// - Track codeunit execution requests with persistent state
/// - Store execution results and timestamps
/// - Enable asynchronous execution patterns via REST API
/// - Provide execution history with success/failure tracking
///
/// State Machine:
/// Pending → Running → Finished (success)
///                  → Error (failure)
///
/// API Endpoint:
/// /api/custom/automation/v1.0/codeunitRunRequests
///
/// Usage Pattern:
/// 1. POST to create new request with CodeunitId
/// 2. POST to .../Microsoft.NAV.runCodeunit action to execute
/// 3. GET to check Status and LastResult
/// 4. Query LastExecutionUTC for execution timestamp
/// </summary>
table 70480 "LIB Test Runner Request"
{
    Caption = 'Test Runner Request';
    DataClassification = SystemMetadata;
    LookupPageId = "LIB Test Runner Requests";
    DrillDownPageId = "LIB Test Runner Requests";

    fields
    {
        /// <summary>
        /// Unique identifier for the execution request (GUID).
        /// </summary>
        /// <remarks>
        /// Auto-generated on insert if not provided.
        /// Used as OData key field for API access.
        /// </remarks>
        field(1; Id; Guid)
        {
            Caption = 'Id';
            DataClassification = SystemMetadata;
        }

        /// <summary>
        /// The ID of the codeunit to execute.
        /// </summary>
        /// <remarks>
        /// Must be set before calling RunCodeunit().
        /// No validation is performed - invalid IDs will result in Error status.
        /// </remarks>
        field(2; CodeunitId; Integer)
        {
            Caption = 'Codeunit Id';
            DataClassification = SystemMetadata;
        }

        /// <summary>
        /// Current execution status of the request.
        /// </summary>
        /// <remarks>
        /// Values:
        /// - Pending: Request created, not yet executed
        /// - Running: Execution in progress (set at start of RunCodeunit)
        /// - Finished: Execution completed successfully
        /// - Error: Execution failed (check LastResult for error message)
        /// </remarks>
        field(3; Status; Option)
        {
            Caption = 'Status';
            OptionMembers = Pending,Running,Finished,Error;
            DataClassification = SystemMetadata;
        }

        /// <summary>
        /// Result message from the last execution attempt.
        /// </summary>
        /// <remarks>
        /// Success: "Success"
        /// Failure: Contains the error message text
        /// Maximum length: 250 characters (error messages may be truncated)
        /// </remarks>
        field(4; LastResult; Text[250])
        {
            Caption = 'Last Result';
            DataClassification = SystemMetadata;
        }

        /// <summary>
        /// Timestamp of the last execution attempt (UTC timezone).
        /// </summary>
        /// <remarks>
        /// Updated by RunCodeunit() procedure.
        /// Always in UTC - convert to local time if needed for display.
        /// </remarks>
        field(5; LastExecutionUTC; DateTime)
        {
            Caption = 'Last Execution (UTC)';
            DataClassification = SystemMetadata;
        }
    }

    keys
    {
        /// <summary>
        /// Primary key on Id field.
        /// </summary>
        key(PK; Id) { Clustered = true; }
    }

    /// <summary>
    /// OnInsert trigger - Initializes new request records.
    /// </summary>
    /// <remarks>
    /// - Auto-generates GUID if not provided
    /// - Defaults Status to Pending (kept via no-op statement)
    /// </remarks>
    trigger OnInsert()
    begin
        if IsNullGuid(Id) then
            Id := CreateGuid();
        if Status = Status::Pending then; // keep default status
    end;
}
