namespace Demo.Library.Test;

using Demo.Library;
using System.TestLibraries.Utilities;

codeunit 70455 "LIB Library Genre Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Any: Codeunit Any;

    [Test]
    procedure TestCreateGenre()
    var
        Genre: Record "LIB Genre";
    begin
        // [GIVEN] A genre code and description
        // [WHEN] A new Genre is created
        Genre.Init();
        Genre.Validate(Code, 'SCIFI');
        Genre.Validate(Description, 'Science Fiction');
        Genre.Insert(true);

        // [THEN] Genre is created successfully
        Assert.AreEqual('SCIFI', Genre.Code, 'Genre code should be set');
        Assert.AreEqual('Science Fiction', Genre.Description, 'Genre description should be set');
    end;

    [Test]
    procedure TestGenreCodeRequired()
    var
        Genre: Record "LIB Genre";
    begin
        // [GIVEN] A Genre without a code
        Genre.Init();

        // [WHEN] Attempting to insert without a code
        // [THEN] An error is thrown because Code is NotBlank
        asserterror Genre.Insert(true);
    end;
}
