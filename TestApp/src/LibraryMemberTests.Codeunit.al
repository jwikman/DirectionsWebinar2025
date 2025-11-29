namespace Demo.Library.Test;

using Demo.Library;
using Microsoft.Foundation.NoSeries;
using System.TestLibraries.Utilities;

codeunit 70450 "LIB Library Member Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Any: Codeunit Any;

    [Test]
    procedure TestCreateLibraryMember()
    var
        LibraryMember: Record "LIB Library Member";
    begin
        // [GIVEN] Library Setup with Member Number Series
        InitializeLibrarySetup();

        // [WHEN] A new Library Member is created
        LibraryMember.Init();
        LibraryMember.Insert(true);

        // [THEN] Member No. is assigned from number series
        Assert.AreNotEqual('', LibraryMember."No.", 'Member No. should be assigned');

        // [THEN] Member Since is set to today
        Assert.AreEqual(Today(), LibraryMember."Member Since", 'Member Since should be today');

        // [THEN] Active is true by default
        Assert.IsTrue(LibraryMember.Active, 'Member should be active by default');
    end;

    [Test]
    procedure TestLibraryMemberEmailValidation()
    var
        LibraryMember: Record "LIB Library Member";
    begin
        // [GIVEN] A Library Member
        InitializeLibrarySetup();
        LibraryMember.Init();
        LibraryMember.Insert(true);

        // [WHEN] Setting a valid email
        LibraryMember.Validate(Email, 'test@example.com');

        // [THEN] Email is accepted
        Assert.AreEqual('test@example.com', LibraryMember.Email, 'Valid email should be accepted');
    end;

    [Test]
    procedure TestLibraryMemberInvalidEmail()
    var
        LibraryMember: Record "LIB Library Member";
    begin
        // [GIVEN] A Library Member
        InitializeLibrarySetup();
        LibraryMember.Init();
        LibraryMember.Insert(true);

        // [WHEN] Setting an invalid email (without @)
        // [THEN] An error is thrown
        asserterror LibraryMember.Validate(Email, 'invalidemail');
        Assert.ExpectedError('The email address is not valid.');
    end;

    [Test]
    procedure TestLibraryMemberMembershipTypes()
    var
        LibraryMember: Record "LIB Library Member";
        MembershipType: Enum "LIB Membership Type";
    begin
        // [GIVEN] A Library Member
        InitializeLibrarySetup();
        LibraryMember.Init();
        LibraryMember.Insert(true);

        // [WHEN] Setting different membership types
        LibraryMember.Validate("Membership Type", MembershipType::Regular);
        Assert.AreEqual(MembershipType::Regular, LibraryMember."Membership Type", 'Should accept Regular');

        LibraryMember.Validate("Membership Type", MembershipType::Student);
        Assert.AreEqual(MembershipType::Student, LibraryMember."Membership Type", 'Should accept Student');

        LibraryMember.Validate("Membership Type", MembershipType::Senior);
        Assert.AreEqual(MembershipType::Senior, LibraryMember."Membership Type", 'Should accept Senior');
    end;

    local procedure InitializeLibrarySetup()
    var
        LibrarySetup: Record "LIB Library Setup";
        NoSeries: Record "No. Series";
    begin
        if not LibrarySetup.Get() then begin
            LibrarySetup.Init();
            LibrarySetup.Insert();
        end;

        // Create Member Number Series
        if LibrarySetup."Member Nos." = '' then begin
            CreateNumberSeries('MEMBER', NoSeries);
            LibrarySetup."Member Nos." := NoSeries.Code;
        end;

        // Create Author Number Series
        if LibrarySetup."Author Nos." = '' then begin
            CreateNumberSeries('AUTHOR', NoSeries);
            LibrarySetup."Author Nos." := NoSeries.Code;
        end;

        // Create Book Number Series
        if LibrarySetup."Book Nos." = '' then begin
            CreateNumberSeries('BOOK', NoSeries);
            LibrarySetup."Book Nos." := NoSeries.Code;
        end;

        // Create Book Loan Number Series
        if LibrarySetup."Book Loan Nos." = '' then begin
            CreateNumberSeries('LOAN', NoSeries);
            LibrarySetup."Book Loan Nos." := NoSeries.Code;
        end;

        // Create Posted Book Loan Number Series
        if LibrarySetup."Posted Book Loan Nos." = '' then begin
            CreateNumberSeries('P-LOAN', NoSeries);
            LibrarySetup."Posted Book Loan Nos." := NoSeries.Code;
        end;

        LibrarySetup.Modify();
    end;

    local procedure CreateNumberSeries(CodePrefix: Code[10]; var NoSeries: Record "No. Series")
    var
        NoSeriesLine: Record "No. Series Line";
    begin
        NoSeries.Init();
        NoSeries.Code := CopyStr(CodePrefix + Format(Any.IntegerInRange(1000, 9999)), 1, MaxStrLen(NoSeries.Code));
        NoSeries.Description := 'Test Series';
        NoSeries."Default Nos." := true;
        NoSeries."Manual Nos." := true;
        if not NoSeries.Insert() then
            NoSeries.Modify();

        NoSeriesLine.SetRange("Series Code", NoSeries.Code);
        if NoSeriesLine.IsEmpty() then begin
            NoSeriesLine.Init();
            NoSeriesLine."Series Code" := NoSeries.Code;
            NoSeriesLine."Line No." := 10000;
            NoSeriesLine."Starting No." := CopyStr(CodePrefix + '00001', 1, MaxStrLen(NoSeriesLine."Starting No."));
            NoSeriesLine."Ending No." := CopyStr(CodePrefix + '99999', 1, MaxStrLen(NoSeriesLine."Ending No."));
            NoSeriesLine.Insert();
        end;
    end;
}
