namespace Demo.Library;

table 70308 "LIB Posted Book Loan Line"
{
    Caption = 'Posted Book Loan Line';
    DataClassification = CustomerContent;
    DataPerCompany = true;
    Extensible = true;
    Access = Public;

    fields
    {
        field(1; "Document No."; Code[20])
        {
            Caption = 'Document No.';
            ToolTip = 'Specifies the document number of the posted book loan.';
            TableRelation = "LIB Posted Book Loan Header";
            AllowInCustomizations = Never;
        }
        field(2; "Line No."; Integer)
        {
            Caption = 'Line No.';
            ToolTip = 'Specifies the line number.';
            AllowInCustomizations = Never;
        }
        field(3; "Book No."; Code[20])
        {
            Caption = 'Book No.';
            ToolTip = 'Specifies the book that was loaned.';
            TableRelation = "LIB Book";
        }
        field(4; "Book Title"; Text[100])
        {
            Caption = 'Book Title';
            ToolTip = 'Specifies the title of the book.';
            FieldClass = FlowField;
            CalcFormula = lookup("LIB Book".Title where("No." = field("Book No.")));
            Editable = false;
        }
        field(5; Quantity; Decimal)
        {
            Caption = 'Quantity';
            ToolTip = 'Specifies the quantity.';
        }
        field(6; "Due Date"; Date)
        {
            Caption = 'Due Date';
            ToolTip = 'Specifies when the book should be returned.';
        }
    }

    keys
    {
        key(Key1; "Document No.", "Line No.")
        {
            Clustered = true;
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "Document No.", "Line No.", "Book No.")
        {
        }
        fieldgroup(Brick; "Document No.", "Line No.", "Book No.")
        {
        }
    }
}
