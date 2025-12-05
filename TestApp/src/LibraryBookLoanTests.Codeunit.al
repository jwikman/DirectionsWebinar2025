namespace Demo.Library.Test;

using Demo.Library;
using Microsoft.Foundation.NoSeries;
using System.TestLibraries.Utilities;

codeunit 70453 "LIB Library Book Loan Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Any: Codeunit Any;

    [Test]
    procedure TestCreateBookLoan()
    var
        BookLoanHeader: Record "LIB Book Loan Header";
    begin
        // [GIVEN] Library Setup with Book Loan Number Series
        InitializeLibrarySetup();

        // [WHEN] A new Book Loan is created
        BookLoanHeader.Init();
        BookLoanHeader.Insert(true);

        // [THEN] Book Loan No. is assigned from number series
        Assert.AreNotEqual('', BookLoanHeader."No.", 'Book Loan No. should be assigned');

        // [THEN] Loan Date is set to today
        Assert.AreEqual(Today(), BookLoanHeader."Loan Date", 'Loan Date should be today');

        // [THEN] Status is Open
        Assert.AreEqual(BookLoanHeader.Status::Open, BookLoanHeader.Status, 'Status should be Open');
    end;

    [Test]
    procedure TestBookLoanExpectedReturnDateValidation()
    var
        BookLoanHeader: Record "LIB Book Loan Header";
    begin
        // [GIVEN] A Book Loan with a loan date
        InitializeLibrarySetup();
        BookLoanHeader.Init();
        BookLoanHeader.Insert(true);

        // [WHEN] Setting a valid expected return date (after loan date)
        BookLoanHeader.Validate("Expected Return Date", Today() + 14);

        // [THEN] Expected return date is accepted
        Assert.AreEqual(Today() + 14, BookLoanHeader."Expected Return Date", 'Valid expected return date should be accepted');
    end;

    [Test]
    procedure TestBookLoanInvalidExpectedReturnDate()
    var
        BookLoanHeader: Record "LIB Book Loan Header";
    begin
        // [GIVEN] A Book Loan with a loan date
        InitializeLibrarySetup();
        BookLoanHeader.Init();
        BookLoanHeader.Insert(true);

        // [WHEN] Setting an invalid expected return date (before loan date)
        // [THEN] An error is thrown
        asserterror BookLoanHeader.Validate("Expected Return Date", Today() - 1);
        Assert.ExpectedError('Expected return date must be after loan date.');
    end;

    [Test]
    procedure TestBookLoanCannotDeletePosted()
    var
        BookLoanHeader: Record "LIB Book Loan Header";
    begin
        // [GIVEN] A posted Book Loan
        InitializeLibrarySetup();
        BookLoanHeader.Init();
        BookLoanHeader.Insert(true);
        BookLoanHeader.Status := BookLoanHeader.Status::Posted;
        BookLoanHeader.Modify();

        // [WHEN] Attempting to delete the posted book loan
        // [THEN] An error is thrown
        asserterror BookLoanHeader.Delete(true);
        Assert.ExpectedError('Cannot delete a posted book loan.');
    end;

    [Test]
    procedure TestBookLoanPostRequiresMember()
    var
        BookLoanHeader: Record "LIB Book Loan Header";
        BookLoanPost: Codeunit "LIB Book Loan-Post";
    begin
        // [GIVEN] A Book Loan without a member
        InitializeLibrarySetup();
        BookLoanHeader.Init();
        BookLoanHeader.Insert(true);

        // [WHEN] Attempting to post the book loan
        // [THEN] An error is thrown
        asserterror BookLoanPost.Run(BookLoanHeader);
        Assert.ExpectedError('Member No. must have a value');
    end;

    [Test]
    procedure TestBookLoanPostRequiresLines()
    var
        BookLoanHeader: Record "LIB Book Loan Header";
        LibraryMember: Record "LIB Library Member";
        BookLoanPost: Codeunit "LIB Book Loan-Post";
    begin
        // [GIVEN] A Book Loan with a member but no lines
        InitializeLibrarySetup();
        CreateLibraryMember(LibraryMember);

        BookLoanHeader.Init();
        BookLoanHeader.Insert(true);
        BookLoanHeader.Validate("Member No.", LibraryMember."No.");
        BookLoanHeader.Modify(true);

        // [WHEN] Attempting to post the book loan
        // [THEN] An error is thrown
        asserterror BookLoanPost.Run(BookLoanHeader);
        Assert.ExpectedError('There are no lines to post');
    end;

    [Test]
    procedure TestBookLoanLineQuantityValidation()
    var
        BookLoanHeader: Record "LIB Book Loan Header";
        BookLoanLine: Record "LIB Book Loan Line";
        Book: Record "LIB Book";
    begin
        // [GIVEN] A Book Loan and a Book
        InitializeLibrarySetup();
        CreateBook(Book);

        BookLoanHeader.Init();
        BookLoanHeader.Insert(true);

        // [WHEN] Creating a loan line with quantity of 1
        BookLoanLine.Init();
        BookLoanLine."Document No." := BookLoanHeader."No.";
        BookLoanLine."Line No." := 10000;
        BookLoanLine.Validate("Book No.", Book."No.");
        BookLoanLine.Validate(Quantity, 1);
        BookLoanLine.Insert(true);

        // [THEN] Line is created successfully
        Assert.AreEqual(1, BookLoanLine.Quantity, 'Quantity should be 1');
        Assert.AreEqual(Book."No.", BookLoanLine."Book No.", 'Book No. should match');
    end;

    [Test]
    procedure TestBookLoanStatusProgression()
    var
        BookLoanHeader: Record "LIB Book Loan Header";
    begin
        // [GIVEN] A new Book Loan
        InitializeLibrarySetup();
        BookLoanHeader.Init();
        BookLoanHeader.Insert(true);

        // [THEN] Status is Open by default
        Assert.AreEqual(BookLoanHeader.Status::Open, BookLoanHeader.Status, 'Status should be Open');

        // [WHEN] Changing status to Posted
        BookLoanHeader.Status := BookLoanHeader.Status::Posted;
        BookLoanHeader.Modify();

        // [THEN] Status is Posted
        Assert.AreEqual(BookLoanHeader.Status::Posted, BookLoanHeader.Status, 'Status should be Posted');
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

    local procedure CreateLibraryMember(var LibraryMember: Record "LIB Library Member")
    begin
        LibraryMember.Init();
        LibraryMember.Insert(true);
        LibraryMember.Validate(Name, 'Test Member');
        LibraryMember.Modify(true);
    end;

    local procedure CreateBook(var Book: Record "LIB Book")
    var
        LibrarySetup: Record "LIB Library Setup";
        NoSeries: Record "No. Series";
    begin
        LibrarySetup.Get();
        if LibrarySetup."Book Nos." = '' then begin
            CreateNumberSeries('BOOK', NoSeries);
            LibrarySetup."Book Nos." := NoSeries.Code;
            LibrarySetup.Modify();
        end;

        Book.Init();
        Book.Insert(true);
        Book.Validate(Title, 'Test Book');
        Book.Validate(Quantity, 5);
        Book.Modify(true);
    end;
}
