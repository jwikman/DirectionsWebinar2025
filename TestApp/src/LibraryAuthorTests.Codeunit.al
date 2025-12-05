namespace Demo.Library.Test;

using Demo.Library;
using Microsoft.Foundation.NoSeries;
using System.TestLibraries.Utilities;

codeunit 70451 "LIB Library Author Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Any: Codeunit Any;

    [Test]
    procedure TestCreateAuthor()
    var
        Author: Record "LIB Author";
    begin
        // [GIVEN] Library Setup with Author Number Series
        InitializeLibrarySetup();

        // [WHEN] A new Author is created
        Author.Init();
        Author.Insert(true);

        // [THEN] Author No. is assigned from number series
        Assert.AreNotEqual('', Author."No.", 'Author No. should be assigned');
    end;

    [Test]
    procedure TestAuthorISNIValidation()
    var
        Author: Record "LIB Author";
    begin
        // [GIVEN] An Author
        InitializeLibrarySetup();
        Author.Init();
        Author.Insert(true);

        // [WHEN] Setting a valid ISNI (16 digits)
        Author.Validate(ISNI, '0000000121032683');

        // [THEN] ISNI is accepted
        Assert.AreEqual('0000000121032683', Author.ISNI, 'Valid ISNI should be accepted');
    end;

    [Test]
    procedure TestAuthorInvalidISNI()
    var
        Author: Record "LIB Author";
    begin
        // [GIVEN] An Author
        InitializeLibrarySetup();
        Author.Init();
        Author.Insert(true);

        // [WHEN] Setting an invalid ISNI (not 16 digits)
        // [THEN] An error is thrown
        asserterror Author.Validate(ISNI, '123456');
        Assert.ExpectedError('ISNI must be exactly 16 digits.');
    end;

    [Test]
    procedure TestAuthorORCIDValidation()
    var
        Author: Record "LIB Author";
    begin
        // [GIVEN] An Author
        InitializeLibrarySetup();
        Author.Init();
        Author.Insert(true);

        // [WHEN] Setting a valid ORCID
        Author.Validate(ORCID, '0000-0002-1825-0097');

        // [THEN] ORCID is accepted
        Assert.AreEqual('0000-0002-1825-0097', Author.ORCID, 'Valid ORCID should be accepted');
    end;

    [Test]
    procedure TestAuthorInvalidORCID()
    var
        Author: Record "LIB Author";
    begin
        // [GIVEN] An Author
        InitializeLibrarySetup();
        Author.Init();
        Author.Insert(true);

        // [WHEN] Setting an invalid ORCID (wrong format)
        // [THEN] An error is thrown
        asserterror Author.Validate(ORCID, '0000-0002-1825');
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

        // Create Author Number Series
        if LibrarySetup."Author Nos." = '' then begin
            CreateNumberSeries('AUTHOR', NoSeries);
            LibrarySetup."Author Nos." := NoSeries.Code;
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
