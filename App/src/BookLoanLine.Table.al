namespace Demo.Library;

table 70306 "LIB Book Loan Line"
{
    Caption = 'Book Loan Line';
    AllowInCustomizations = AsReadOnly;
    DataClassification = CustomerContent;
    DataPerCompany = true;
    Extensible = true;
    Access = Public;

    fields
    {
        field(1; "Document No."; Code[20])
        {
            Caption = 'Document No.';
            ToolTip = 'Specifies the document number of the book loan.';
            TableRelation = "LIB Book Loan Header";
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
            ToolTip = 'Specifies the book being loaned.';
            TableRelation = "LIB Book";

            trigger OnValidate()
            begin
                CalcFields("Book Title");
            end;
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
            ToolTip = 'Specifies the quantity (must be 1).';
            InitValue = 1;
            MinValue = 1;
            MaxValue = 1;

            trigger OnValidate()
            var
                InvalidQuantityErr: Label 'Quantity must be exactly 1 for book loans.';
            begin
                if Quantity <> 1 then
                    Error(InvalidQuantityErr);
            end;
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

    trigger OnInsert()
    var
        BookLoanHeader: Record "LIB Book Loan Header";
    begin
        if BookLoanHeader.Get("Document No.") then
            if "Due Date" = 0D then
                "Due Date" := BookLoanHeader."Expected Return Date";
    end;
}
