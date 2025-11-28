namespace Demo.Library.Tests;

using Demo.Library;
using System.TestLibraries.Utilities;

codeunit 70450 "LIB Library Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Any: Codeunit Any;

    [Test]
    procedure CreateAuthor()
    var
        Author: Record "LIB Author";
        AuthorName: Text[100];
        AuthorCountry: Text[50];
    begin
        // [SCENARIO] Creating an author record with valid data
        // [GIVEN] Author details
        AuthorName := CopyStr(Any.AlphanumericText(100), 1, 100);
        AuthorCountry := CopyStr(Any.AlphanumericText(50), 1, 50);

        // [WHEN] Creating an author
        Author.Init();
        Author."No." := 'TEST-AUTH-001';
        Author.Name := AuthorName;
        Author.Country := AuthorCountry;
        Author.Insert(true);

        // [THEN] The author is created with correct values
        Assert.AreEqual(AuthorName, Author.Name, 'Author name should match');
        Assert.AreEqual(AuthorCountry, Author.Country, 'Author country should match');
    end;

    [Test]
    procedure CreateBook()
    var
        Book: Record "LIB Book";
        BookTitle: Text[100];
    begin
        // [SCENARIO] Creating a book record with valid data
        // [GIVEN] Book details
        BookTitle := CopyStr(Any.AlphanumericText(100), 1, 100);

        // [WHEN] Creating a book
        Book.Init();
        Book."No." := 'TEST-BOOK-001';
        Book.Title := BookTitle;
        Book."Publication Year" := Date2DMY(Today(), 3);
        Book.Quantity := 5;
        Book.Insert(true);

        // [THEN] The book is created with correct values
        Assert.AreEqual(BookTitle, Book.Title, 'Book title should match');
        Assert.AreEqual(5, Book.Quantity, 'Book quantity should match');
    end;

    [Test]
    procedure CreateLibraryMember()
    var
        Member: Record "LIB Library Member";
        MemberName: Text[100];
        MemberEmail: Text[80];
    begin
        // [SCENARIO] Creating a library member with valid data
        // [GIVEN] Member details
        MemberName := CopyStr(Any.AlphanumericText(100), 1, 100);
        MemberEmail := 'test@example.com';

        // [WHEN] Creating a library member
        Member.Init();
        Member."No." := 'TEST-MEMB-001';
        Member.Name := MemberName;
        Member.Email := MemberEmail;
        Member.Active := true;
        Member.Insert(true);

        // [THEN] The library member is created with correct values
        Assert.AreEqual(MemberName, Member.Name, 'Member name should match');
        Assert.AreEqual(MemberEmail, Member.Email, 'Member email should match');
        Assert.IsTrue(Member.Active, 'Member should be active');
    end;

    [Test]
    procedure ValidateISBNFormat()
    var
        Book: Record "LIB Book";
    begin
        // [SCENARIO] ISBN validation accepts valid format
        // [GIVEN] A book record
        Book.Init();
        Book."No." := 'TEST-BOOK-002';

        // [WHEN] Setting a valid ISBN with numbers and hyphens
        Book.Validate(ISBN, '978-3-16-148410-0');

        // [THEN] The ISBN is accepted
        Assert.AreEqual('978-3-16-148410-0', Book.ISBN, 'ISBN should be set correctly');
    end;

    [Test]
    procedure ValidateEmailContainsAtSymbol()
    var
        Member: Record "LIB Library Member";
    begin
        // [SCENARIO] Email validation requires @ symbol
        // [GIVEN] A library member record
        Member.Init();
        Member."No." := 'TEST-MEMB-002';

        // [WHEN] Setting a valid email
        Member.Validate(Email, 'user@domain.com');

        // [THEN] The email is accepted
        Assert.AreEqual('user@domain.com', Member.Email, 'Email should be set correctly');
    end;
}
