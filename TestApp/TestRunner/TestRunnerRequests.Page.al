/// <summary>
/// Test Runner Requests API - REST endpoint for state-tracked codeunit execution
///
/// This API page exposes the Test Runner Request table via OData/REST endpoints,
/// enabling remote codeunit execution with persistent state tracking.
///
/// Endpoint:
/// /api/custom/automation/v1.0/codeunitRunRequests
///
/// Operations:
/// - GET: List all execution requests
/// - GET(id): Retrieve specific request by GUID
/// - POST: Create new execution request
/// - PATCH(id): Update request fields (e.g., CodeunitId)
/// - DELETE(id): Remove execution request
/// - POST(id)/Microsoft.NAV.runCodeunit: Execute the codeunit (service-enabled action)
/// </summary>
page 70480 "LIB Test Runner Requests"
{
    PageType = API;
    Caption = 'Test Runner Requests';
    APIPublisher = 'custom';
    APIGroup = 'automation';
    APIVersion = 'v1.0';
    EntityName = 'codeunitRunRequest';
    EntitySetName = 'codeunitRunRequests';
    SourceTable = "LIB Test Runner Request";
    DelayedInsert = true;
    ODataKeyFields = Id;

    layout
    {
        area(content)
        {
            group(General)
            {
                field(id; Rec.Id) { Editable = false; }
                field(codeunitId; Rec.CodeunitId) { }
                field(status; Rec.Status) { Editable = false; }
                field(lastResult; Rec.LastResult) { Editable = false; }
                field(lastExecutionUTC; Rec.LastExecutionUTC) { Editable = false; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(RunNow)
            {
                Caption = 'Run';
                ApplicationArea = All;
                trigger OnAction()
                begin
                    RunCodeunit();
                end;
            }
        }
    }

    /// <summary>
    /// Executes the codeunit specified in the CodeunitId field.
    /// Service-enabled procedure callable via REST API.
    /// </summary>
    /// <returns>True if execution succeeded, False if it failed</returns>
    /// <remarks>
    /// REST API Endpoint:
    /// POST .../codeunitRunRequests(guid'{id}')/Microsoft.NAV.runCodeunit
    ///
    /// Behavior:
    /// 1. Validates CodeunitId is set (TestField)
    /// 2. Prevents concurrent execution (checks for Running status)
    /// 3. Sets status to Running
    /// 4. Executes codeunit via Codeunit.Run()
    /// 5. Updates status to Finished (success) or Error (failure)
    /// 6. Captures error message in LastResult on failure
    /// 7. Records execution timestamp in LastExecutionUTC
    ///
    /// Error Handling:
    /// - Throws error if CodeunitId is not set
    /// - Throws error if already Running
    /// - Captures GetLastErrorText() on execution failure
    /// - Updates record even if execution fails
    ///
    /// Note: This uses the Test Runner API (codeunit 70480).
    /// It properly handles both test codeunits (Subtype = Test) and regular codeunits.
    /// </remarks>
    [ServiceEnabled]
    procedure RunCodeunit(): Boolean
    var
        Log: Record "LIB Test Log";
        TestRunnerAPI: Codeunit "LIB Test Runner";
        Success: Boolean;
        FailedTests: Integer;
        TestsFailedLbl: Label '%1 test(s) failed - check logs for details', Comment = '%1 = number of failed tests';
    begin
        Rec.TestField(CodeunitId);
        if Rec.Status = Rec.Status::Running then
            Error('Already running.');

        Rec.Status := Rec.Status::Running;
        Rec.Modify(true);

        // Use the Test Runner API to execute the codeunit
        // This properly handles both test codeunits (Subtype = Test) and regular codeunits
        ClearLastError();
        Commit(); // Required before running test codeunits to ensure clean transaction state

        TestRunnerAPI.SetCodeunitId(Rec.CodeunitId);
        Success := TestRunnerAPI.Run();

        // Check if any individual tests failed
        Log.SetRange(Success, false);
        FailedTests := Log.Count();

        if Success and (FailedTests = 0) then begin
            Rec.Status := Rec.Status::Finished;
            Rec.LastResult := 'Success';
        end else begin
            Rec.Status := Rec.Status::Error;
            if FailedTests > 0 then
                Rec.LastResult := StrSubstNo(TestsFailedLbl, FailedTests)
            else begin
                Rec.LastResult := CopyStr(GetLastErrorText(), 1, 250);
                if Rec.LastResult = '' then
                    Rec.LastResult := 'Unknown error - check logs for details';
            end;
        end;

        Rec.LastExecutionUTC := CurrentDateTime();
        Rec.Modify(true);
        exit(Success and (FailedTests = 0));
    end;
}
