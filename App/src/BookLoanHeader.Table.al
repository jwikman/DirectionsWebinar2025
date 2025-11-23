namespace Demo.Library;

using Microsoft.Foundation.NoSeries;

table 70305 "LIB Book Loan Header"
{
    Caption = 'Book Loan Header';
    DataClassification = CustomerContent;
    DataPerCompany = true;
    Extensible = true;
    Access = Public;
    LookupPageId = "LIB Book Loan List";
    DrillDownPageId = "LIB Book Loan List";

    fields
    {
        field(1; "No."; Code[20])
        {
            Caption = 'No.';
            ToolTip = 'Specifies the unique identifier for the book loan.';

            trigger OnValidate()
            var
                LibrarySetup: Record "LIB Library Setup";
                NoSeries: Codeunit "No. Series";
            begin
                if "No." <> xRec."No." then begin
                    LibrarySetup.Get();
                    NoSeries.TestManual(LibrarySetup."Book Loan Nos.");
                    "No. Series" := '';
                end;
            end;
        }
        field(2; "Member No."; Code[20])
        {
            Caption = 'Member No.';
            ToolTip = 'Specifies the library member borrowing the books.';
            TableRelation = "LIB Library Member";

            trigger OnValidate()
            begin
                CalcFields("Member Name");
            end;
        }
        field(3; "Member Name"; Text[100])
        {
            Caption = 'Member Name';
            ToolTip = 'Specifies the name of the library member.';
            FieldClass = FlowField;
            CalcFormula = lookup("LIB Library Member".Name where("No." = field("Member No.")));
            Editable = false;
        }
        field(4; "Loan Date"; Date)
        {
            Caption = 'Loan Date';
            ToolTip = 'Specifies the date when the books are loaned.';
        }
        field(5; "Expected Return Date"; Date)
        {
            Caption = 'Expected Return Date';
            ToolTip = 'Specifies the expected return date for the loaned books.';

            trigger OnValidate()
            var
                InvalidDateErr: Label 'Expected return date must be after loan date.';
            begin
                if ("Expected Return Date" <> 0D) and ("Loan Date" <> 0D) then
                    if "Expected Return Date" <= "Loan Date" then
                        Error(InvalidDateErr);
            end;
        }
        field(6; Status; Enum "LIB Book Loan Status")
        {
            Caption = 'Status';
            ToolTip = 'Specifies the status of the book loan (Open or Posted).';
            Editable = false;
        }
        field(7; "No. of Lines"; Integer)
        {
            Caption = 'No. of Lines';
            ToolTip = 'Specifies the number of lines in the book loan.';
            FieldClass = FlowField;
            CalcFormula = count("LIB Book Loan Line" where("Document No." = field("No.")));
            Editable = false;
        }
        field(10; "No. Series"; Code[20])
        {
            Caption = 'No. Series';
            ToolTip = 'Specifies the number series from which the loan number was assigned.';
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
        fieldgroup(DropDown; "No.", "Member No.", "Loan Date")
        {
        }
        fieldgroup(Brick; "No.", "Member No.", "Loan Date")
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
            LibrarySetup.TestField("Book Loan Nos.");
            "No. Series" := LibrarySetup."Book Loan Nos.";
            "No." := NoSeries.GetNextNo(LibrarySetup."Book Loan Nos.");
        end;

        if "Loan Date" = 0D then
            "Loan Date" := Today();

        Status := Status::Open;
    end;

    trigger OnDelete()
    var
        BookLoanLine: Record "LIB Book Loan Line";
        CannotDeletePostedErr: Label 'Cannot delete a posted book loan.';
    begin
        if Status = Status::Posted then
            Error(CannotDeletePostedErr);

        BookLoanLine.SetRange("Document No.", "No.");
        BookLoanLine.DeleteAll(true);
    end;

    /// <summary>
    /// Enables the user to select a number series for the book loan.
    /// </summary>
    /// <param name="OldBookLoan">The previous book loan record state.</param>
    /// <returns>True if a number series was selected; otherwise, false.</returns>
    procedure AssistEdit(OldBookLoan: Record "LIB Book Loan Header"): Boolean
    var
        LibrarySetup: Record "LIB Library Setup";
        NoSeries: Codeunit "No. Series";
    begin
        LibrarySetup.Get();
        LibrarySetup.TestField("Book Loan Nos.");
        if NoSeries.LookupRelatedNoSeries(LibrarySetup."Book Loan Nos.", OldBookLoan."No. Series", "No. Series") then begin
            "No." := NoSeries.GetNextNo("No. Series");
            exit(true);
        end;
    end;
}
