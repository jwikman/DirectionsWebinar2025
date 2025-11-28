namespace Demo.Library.Test;

using Demo.Library;
using System.TestLibraries.Utilities;

codeunit 70450 "LIB Library Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        LibraryAssert: Codeunit "Library Assert";
        LibraryVariableStorage: Codeunit "Library - Variable Storage";
        IsInitialized: Boolean;

    [Test]
    procedure TestGenreCreation()
    var
        Genre: Record "LIB Genre";
    begin
        // [SCENARIO] Create a new genre record
        Initialize();

        // [GIVEN] A genre record with code and description
        // [WHEN] The genre is inserted
        Genre.Init();
        Genre.Code := 'FICTION';
        Genre.Description := 'Fiction Books';
        Genre.Insert(true);

        // [THEN] The genre should exist in the database
        LibraryAssert.IsTrue(Genre.Get('FICTION'), 'Genre should exist after insert');
        LibraryAssert.AreEqual('Fiction Books', Genre.Description, 'Genre description should match');
    end;

    [Test]
    procedure TestGenreCodeIsRequired()
    var
        Genre: Record "LIB Genre";
    begin
        // [SCENARIO] Genre code field is required (NotBlank)
        Initialize();

        // [GIVEN] A genre record without a code
        Genre.Init();
        Genre.Description := 'Test Description';

        // [WHEN] Trying to insert without a code
        // [THEN] An error should occur due to NotBlank constraint
        asserterror Genre.Insert(true);
        LibraryAssert.ExpectedError('');
    end;

    [Test]
    procedure TestAuthorISNIValidation()
    var
        Author: Record "LIB Author";
        InvalidISNI: Text[16];
    begin
        // [SCENARIO] ISNI must be exactly 16 digits
        Initialize();

        // [GIVEN] An author record
        Author.Init();
        Author."No." := 'AUTH-001';
        Author.Name := 'Test Author';

        // [WHEN] Setting an invalid ISNI (less than 16 digits)
        InvalidISNI := '123456789012345';

        // [THEN] Validation should fail
        asserterror Author.Validate(ISNI, InvalidISNI);
        LibraryAssert.ExpectedError('ISNI must be exactly 16 digits');
    end;

    [Test]
    procedure TestAuthorValidISNI()
    var
        Author: Record "LIB Author";
        ValidISNI: Text[16];
    begin
        // [SCENARIO] Valid ISNI should be accepted
        Initialize();

        // [GIVEN] An author record
        Author.Init();
        Author."No." := 'AUTH-002';
        Author.Name := 'Test Author';

        // [WHEN] Setting a valid ISNI (exactly 16 digits)
        ValidISNI := '0000000121212121';
        Author.Validate(ISNI, ValidISNI);

        // [THEN] The ISNI should be set correctly
        LibraryAssert.AreEqual(ValidISNI, Author.ISNI, 'ISNI should be set to valid value');
    end;

    [Test]
    procedure TestAuthorORCIDValidation()
    var
        Author: Record "LIB Author";
        InvalidORCID: Text[19];
    begin
        // [SCENARIO] ORCID must be in format 0000-0000-0000-0000
        Initialize();

        // [GIVEN] An author record
        Author.Init();
        Author."No." := 'AUTH-003';
        Author.Name := 'Test Author';

        // [WHEN] Setting an invalid ORCID format
        InvalidORCID := '00000000000000000';

        // [THEN] Validation should fail
        asserterror Author.Validate(ORCID, InvalidORCID);
        LibraryAssert.ExpectedError('ORCID must be in format');
    end;

    [Test]
    procedure TestAuthorValidORCID()
    var
        Author: Record "LIB Author";
        ValidORCID: Text[19];
    begin
        // [SCENARIO] Valid ORCID format should be accepted
        Initialize();

        // [GIVEN] An author record
        Author.Init();
        Author."No." := 'AUTH-004';
        Author.Name := 'Test Author';

        // [WHEN] Setting a valid ORCID format
        ValidORCID := '0000-0002-1825-0097';
        Author.Validate(ORCID, ValidORCID);

        // [THEN] The ORCID should be set correctly
        LibraryAssert.AreEqual(ValidORCID, Author.ORCID, 'ORCID should be set to valid value');
    end;

    [Test]
    procedure TestBookISBNValidation()
    var
        Book: Record "LIB Book";
    begin
        // [SCENARIO] ISBN should only contain numbers and hyphens
        Initialize();

        // [GIVEN] A book record
        Book.Init();
        Book."No." := 'BOOK-001';
        Book.Title := 'Test Book';

        // [WHEN] Setting an invalid ISBN with letters
        // [THEN] Validation should fail
        asserterror Book.Validate(ISBN, '978-3-16-14ABC');
        LibraryAssert.ExpectedError('ISBN must contain only numbers and hyphens');
    end;

    [Test]
    procedure TestBookValidISBN()
    var
        Book: Record "LIB Book";
        ValidISBN: Code[20];
    begin
        // [SCENARIO] Valid ISBN should be accepted
        Initialize();

        // [GIVEN] A book record
        Book.Init();
        Book."No." := 'BOOK-002';
        Book.Title := 'Test Book';

        // [WHEN] Setting a valid ISBN
        ValidISBN := '978-3-16-148410-0';
        Book.Validate(ISBN, ValidISBN);

        // [THEN] The ISBN should be set correctly
        LibraryAssert.AreEqual(ValidISBN, Book.ISBN, 'ISBN should be set to valid value');
    end;

    [Test]
    procedure TestBookPublicationYearValidation()
    var
        Book: Record "LIB Book";
    begin
        // [SCENARIO] Publication year must be valid (1 to current year)
        Initialize();

        // [GIVEN] A book record
        Book.Init();
        Book."No." := 'BOOK-003';
        Book.Title := 'Test Book';

        // [WHEN] Setting a future publication year
        // [THEN] Validation should fail
        asserterror Book.Validate("Publication Year", Today().Year() + 1);
        LibraryAssert.ExpectedError('Publication year must be between 1 and');
    end;

    [Test]
    procedure TestBookQuantityCannotBeNegative()
    var
        Book: Record "LIB Book";
    begin
        // [SCENARIO] Book quantity cannot be negative
        Initialize();

        // [GIVEN] A book record
        Book.Init();
        Book."No." := 'BOOK-004';
        Book.Title := 'Test Book';

        // [WHEN] Setting a negative quantity
        // [THEN] Validation should fail
        asserterror Book.Validate(Quantity, -1);
        LibraryAssert.ExpectedError('Quantity cannot be negative');
    end;

    [Test]
    procedure TestLibraryMemberEmailValidation()
    var
        LibraryMember: Record "LIB Library Member";
    begin
        // [SCENARIO] Email must contain @ symbol
        Initialize();

        // [GIVEN] A library member record
        LibraryMember.Init();
        LibraryMember."No." := 'MEM-001';
        LibraryMember.Name := 'Test Member';

        // [WHEN] Setting an invalid email without @
        // [THEN] Validation should fail
        asserterror LibraryMember.Validate(Email, 'invalidemail.com');
        LibraryAssert.ExpectedError('The email address is not valid');
    end;

    [Test]
    procedure TestLibraryMemberValidEmail()
    var
        LibraryMember: Record "LIB Library Member";
        ValidEmail: Text[80];
    begin
        // [SCENARIO] Valid email should be accepted
        Initialize();

        // [GIVEN] A library member record
        LibraryMember.Init();
        LibraryMember."No." := 'MEM-002';
        LibraryMember.Name := 'Test Member';

        // [WHEN] Setting a valid email
        ValidEmail := 'test@example.com';
        LibraryMember.Validate(Email, ValidEmail);

        // [THEN] The email should be set correctly
        LibraryAssert.AreEqual(ValidEmail, LibraryMember.Email, 'Email should be set to valid value');
    end;

    local procedure Initialize()
    begin
        LibraryVariableStorage.Clear();

        if IsInitialized then
            exit;

        IsInitialized := true;
        Commit();
    end;
}
