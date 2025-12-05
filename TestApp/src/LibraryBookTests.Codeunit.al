namespace Demo.Library.Test;

using Demo.Library;
using Microsoft.Foundation.NoSeries;
using System.TestLibraries.Utilities;

codeunit 70452 "LIB Library Book Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Any: Codeunit Any;

    [Test]
    procedure TestCreateBook()
    var
        Book: Record "LIB Book";
    begin
        // [GIVEN] Library Setup with Book Number Series
        InitializeLibrarySetup();

        // [WHEN] A new Book is created
        Book.Init();
        Book.Insert(true);

        // [THEN] Book No. is assigned from number series
        Assert.AreNotEqual('', Book."No.", 'Book No. should be assigned');
    end;

    [Test]
    procedure TestBookISBNValidation()
    var
        Book: Record "LIB Book";
    begin
        // [GIVEN] A Book
        InitializeLibrarySetup();
        Book.Init();
        Book.Insert(true);

        // [WHEN] Setting a valid ISBN
        Book.Validate(ISBN, '978-3-16-148410-0');

        // [THEN] ISBN is accepted
        Assert.AreEqual('978-3-16-148410-0', Book.ISBN, 'Valid ISBN should be accepted');
    end;

    [Test]
    procedure TestBookInvalidISBN()
    var
        Book: Record "LIB Book";
    begin
        // [GIVEN] A Book
        InitializeLibrarySetup();
        Book.Init();
        Book.Insert(true);

        // [WHEN] Setting an invalid ISBN (with letters)
        // [THEN] An error is thrown
        asserterror Book.Validate(ISBN, '978-ABC-123');
        Assert.ExpectedError('ISBN must contain only numbers and hyphens.');
    end;

    [Test]
    procedure TestBookPublicationYearValidation()
    var
        Book: Record "LIB Book";
    begin
        // [GIVEN] A Book
        InitializeLibrarySetup();
        Book.Init();
        Book.Insert(true);

        // [WHEN] Setting a valid publication year
        Book.Validate("Publication Year", 2020);

        // [THEN] Publication year is accepted
        Assert.AreEqual(2020, Book."Publication Year", 'Valid publication year should be accepted');
    end;

    [Test]
    procedure TestBookInvalidPublicationYear()
    var
        Book: Record "LIB Book";
    begin
        // [GIVEN] A Book
        InitializeLibrarySetup();
        Book.Init();
        Book.Insert(true);

        // [WHEN] Setting an invalid publication year (future)
        // [THEN] An error is thrown
        asserterror Book.Validate("Publication Year", Today().Year() + 10);
    end;

    [Test]
    procedure TestBookQuantityValidation()
    var
        Book: Record "LIB Book";
    begin
        // [GIVEN] A Book
        InitializeLibrarySetup();
        Book.Init();
        Book.Insert(true);

        // [WHEN] Setting a valid quantity
        Book.Validate(Quantity, 5);

        // [THEN] Quantity is accepted
        Assert.AreEqual(5, Book.Quantity, 'Valid quantity should be accepted');
    end;

    [Test]
    procedure TestBookNegativeQuantity()
    var
        Book: Record "LIB Book";
    begin
        // [GIVEN] A Book
        InitializeLibrarySetup();
        Book.Init();
        Book.Insert(true);

        // [WHEN] Setting a negative quantity
        // [THEN] An error is thrown
        asserterror Book.Validate(Quantity, -1);
        Assert.ExpectedError('Quantity cannot be negative.');
    end;

    [Test]
    procedure TestBookTitleRequired()
    var
        Book: Record "LIB Book";
    begin
        // [GIVEN] Library Setup with Book Number Series
        InitializeLibrarySetup();

        // [WHEN] Creating a book with a title
        Book.Init();
        Book.Insert(true);
        Book.Validate(Title, 'The Great Book');
        Book.Modify(true);

        // [THEN] Book title is set correctly
        Assert.AreEqual('The Great Book', Book.Title, 'Book title should be set');
    end;

    [Test]
    procedure TestBookAvailableQuantityCalculation()
    var
        Book: Record "LIB Book";
    begin
        // [GIVEN] A Book with quantity
        InitializeLibrarySetup();
        Book.Init();
        Book.Insert(true);
        Book.Validate(Quantity, 5);
        Book.Modify(true);

        // [WHEN] Calculating available quantity with no loans
        Book.CalcFields("Available Quantity");

        // [THEN] Total quantity is set
        Assert.AreEqual(5, Book.Quantity, 'Total quantity should be 5');
        Assert.AreEqual(0, Book."Available Quantity", 'Available quantity should be 0 initially (no loans)');
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

        // Create Book Number Series
        if LibrarySetup."Book Nos." = '' then begin
            CreateNumberSeries('BOOK', NoSeries);
            LibrarySetup."Book Nos." := NoSeries.Code;
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
