codeunit 70454 "LIB Test Suite"
{
    // version 2021-02-23

    [EventSubscriber(ObjectType::Page, Page::"AL Test Tool", 'OnOpenPageEvent', '', false, false)]
    local procedure ALTestTool_OnOpenPageEvent()
    begin
        Create('LIB');
    end;

    procedure Create(TestSuiteName: Code[10])
    var
        ALTestSuite: Record "AL Test Suite";
        TestSuiteMgt: Codeunit "Test Suite Mgt.";
    begin
        if ALTestSuite.Get(TestSuiteName) then
            exit;

        TestSuiteMgt.CreateTestSuite(TestSuiteName);
        ALTestSuite.Get(TestSuiteName);
        TestSuiteMgt.SelectTestMethodsByExtension(ALTestSuite, GetCurrentAppId());
    end;

    local procedure GetCurrentAppId(): Guid
    var
        CurrentApp: ModuleInfo;
    begin
        NavApp.GetCurrentModuleInfo(CurrentApp);
        exit(CurrentApp.Id());
    end;
}