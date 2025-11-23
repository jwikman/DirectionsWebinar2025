namespace Demo.Library;

using Microsoft.Foundation.NoSeries;

table 70303 "LIB Book"
{
    Caption = 'Book';
    DataClassification = CustomerContent;
    DataPerCompany = true;
    Extensible = true;
    Access = Public;
    LookupPageId = "LIB Book List";
    DrillDownPageId = "LIB Book List";

    fields
    {
        field(1; "No."; Code[20])
        {
            Caption = 'No.';
            ToolTip = 'Specifies the unique identifier for the book.';

            trigger OnValidate()
            var
                LibrarySetup: Record "LIB Library Setup";
                NoSeries: Codeunit "No. Series";
            begin
                if "No." <> xRec."No." then begin
                    LibrarySetup.Get();
                    NoSeries.TestManual(LibrarySetup."Book Nos.");
                    "No. Series" := '';
                end;
            end;
        }
        field(2; Title; Text[100])
        {
            Caption = 'Title';
            ToolTip = 'Specifies the title of the book.';
        }
        field(3; "Author No."; Code[20])
        {
            Caption = 'Author No.';
            ToolTip = 'Specifies the author of the book.';
            TableRelation = "LIB Author";
        }
        field(4; ISBN; Code[20])
        {
            Caption = 'ISBN';
            ToolTip = 'Specifies the International Standard Book Number.';

            trigger OnValidate()
            var
                InvalidISBNFormatErr: Label 'ISBN must contain only numbers and hyphens.';
                i: Integer;
            begin
                if ISBN = '' then
                    exit;

                for i := 1 to StrLen(ISBN) do
                    if not (ISBN[i] in ['0' .. '9', '-']) then
                        Error(InvalidISBNFormatErr);
            end;
        }
        field(5; "Genre Code"; Code[20])
        {
            Caption = 'Genre Code';
            ToolTip = 'Specifies the genre of the book.';
            TableRelation = "LIB Genre";
        }
        field(6; "Publication Year"; Integer)
        {
            Caption = 'Publication Year';
            ToolTip = 'Specifies the year the book was published.';

            trigger OnValidate()
            var
                InvalidYearErr: Label 'Publication year must be between 1 and %1.', Comment = '%1 = current year';
            begin
                if "Publication Year" = 0 then
                    exit;

                if ("Publication Year" < 1) or ("Publication Year" > Today().Year()) then
                    Error(InvalidYearErr, Today().Year());
            end;
        }
        field(7; Quantity; Integer)
        {
            Caption = 'Quantity';
            ToolTip = 'Specifies the total number of copies owned.';
            MinValue = 0;

            trigger OnValidate()
            var
                NegativeQuantityErr: Label 'Quantity cannot be negative.';
            begin
                if Quantity < 0 then
                    Error(NegativeQuantityErr);
            end;
        }
        field(8; "Available Quantity"; Integer)
        {
            Caption = 'Available Quantity';
            ToolTip = 'Specifies the number of copies currently available for loan.';
            FieldClass = FlowField;
            CalcFormula = sum("LIB Book Loan Ledger Entry".Quantity where("Book No." = field("No.")));
            Editable = false;
        }
        field(9; Description; Text[250])
        {
            Caption = 'Description';
            ToolTip = 'Specifies a description of the book.';
        }
        field(10; "No. Series"; Code[20])
        {
            Caption = 'No. Series';
            ToolTip = 'Specifies the number series from which the book number was assigned.';
            TableRelation = "No. Series";
            Editable = false;
            AllowInCustomizations = Never;
        }
    }

    keys
    {
        key(Key1; "No.")
        {
            Clustered = true;
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "No.", Title, "Author No.")
        {
        }
        fieldgroup(Brick; "No.", Title)
        {
        }
    }

    trigger OnInsert()
    var
        LibrarySetup: Record "LIB Library Setup";
        NoSeries: Codeunit "No. Series";
    begin
        if "No." = '' then begin
            LibrarySetup.Get();
            LibrarySetup.TestField("Book Nos.");
            "No. Series" := LibrarySetup."Book Nos.";
            "No." := NoSeries.GetNextNo(LibrarySetup."Book Nos.");
        end;
    end;

    /// <summary>
    /// Enables the user to select a number series for the book.
    /// </summary>
    /// <param name="OldBook">The previous book record state.</param>
    /// <returns>True if a number series was selected; otherwise, false.</returns>
    procedure AssistEdit(OldBook: Record "LIB Book"): Boolean
    var
        LibrarySetup: Record "LIB Library Setup";
        NoSeries: Codeunit "No. Series";
    begin
        LibrarySetup.Get();
        LibrarySetup.TestField("Book Nos.");
        if NoSeries.LookupRelatedNoSeries(LibrarySetup."Book Nos.", OldBook."No. Series", "No. Series") then begin
            "No." := NoSeries.GetNextNo("No. Series");
            exit(true);
        end;
    end;
}
