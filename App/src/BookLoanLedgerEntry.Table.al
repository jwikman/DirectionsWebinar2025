namespace Demo.Library;

table 70309 "LIB Book Loan Ledger Entry"
{
    Caption = 'Book Loan Ledger Entry';
    DataClassification = CustomerContent;
    DataPerCompany = true;
    Extensible = true;
    Access = Public;
    LookupPageId = "LIB Book Loan Ledger Entries";
    DrillDownPageId = "LIB Book Loan Ledger Entries";

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            ToolTip = 'Specifies the entry number.';
            AutoIncrement = true;
        }
        field(2; "Book No."; Code[20])
        {
            Caption = 'Book No.';
            ToolTip = 'Specifies the book number.';
            TableRelation = "LIB Book";
        }
        field(3; "Member No."; Code[20])
        {
            Caption = 'Member No.';
            ToolTip = 'Specifies the member number.';
            TableRelation = "LIB Library Member";
        }
        field(4; "Posting Date"; Date)
        {
            Caption = 'Posting Date';
            ToolTip = 'Specifies the posting date.';
        }
        field(5; "Document No."; Code[20])
        {
            Caption = 'Document No.';
            ToolTip = 'Specifies the document number.';
        }
        field(6; "Entry Type"; Enum "LIB Book Loan Entry Type")
        {
            Caption = 'Entry Type';
            ToolTip = 'Specifies the entry type (Loan or Return).';
        }
        field(7; Quantity; Decimal)
        {
            Caption = 'Quantity';
            ToolTip = 'Specifies the quantity (positive for loan, negative for return).';
        }
        field(8; "Loan Date"; Date)
        {
            Caption = 'Loan Date';
            ToolTip = 'Specifies when the book was loaned.';
        }
        field(9; "Due Date"; Date)
        {
            Caption = 'Due Date';
            ToolTip = 'Specifies when the book should be returned.';
        }
        field(10; "Return Date"; Date)
        {
            Caption = 'Return Date';
            ToolTip = 'Specifies when the book was actually returned (for Return entries).';
        }
    }

    keys
    {
        key(Key1; "Entry No.")
        {
            Clustered = true;
        }
        key(Key2; "Book No.", "Entry Type")
        {
            SumIndexFields = Quantity;
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "Entry No.", "Book No.", "Member No.", "Entry Type")
        {
        }
        fieldgroup(Brick; "Entry No.", "Book No.", "Member No.", "Entry Type")
        {
        }
    }
}
