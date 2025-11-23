namespace Demo.Library;

table 70307 "LIB Posted Book Loan Header"
{
    Caption = 'Posted Book Loan Header';
    DataClassification = CustomerContent;
    DataPerCompany = true;
    Extensible = true;
    Access = Public;
    LookupPageId = "LIB Posted Book Loan List";
    DrillDownPageId = "LIB Posted Book Loan List";

    fields
    {
        field(1; "No."; Code[20])
        {
            Caption = 'No.';
            ToolTip = 'Specifies the unique identifier for the posted book loan.';
            NotBlank = true;
        }
        field(2; "Member No."; Code[20])
        {
            Caption = 'Member No.';
            ToolTip = 'Specifies the library member who borrowed the books.';
            TableRelation = "LIB Library Member";
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
            ToolTip = 'Specifies the date when the books were loaned.';
        }
        field(5; "Expected Return Date"; Date)
        {
            Caption = 'Expected Return Date';
            ToolTip = 'Specifies the expected return date for the loaned books.';
        }
        field(7; "No. of Lines"; Integer)
        {
            Caption = 'No. of Lines';
            ToolTip = 'Specifies the number of lines in the posted book loan.';
            FieldClass = FlowField;
            CalcFormula = count("LIB Posted Book Loan Line" where("Document No." = field("No.")));
            Editable = false;
        }
        field(11; "Posting Date"; Date)
        {
            Caption = 'Posting Date';
            ToolTip = 'Specifies the posting date of the book loan.';
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
        fieldgroup(DropDown; "No.", "Member No.", "Posting Date")
        {
        }
        fieldgroup(Brick; "No.", "Member No.", "Posting Date")
        {
        }
    }
}
