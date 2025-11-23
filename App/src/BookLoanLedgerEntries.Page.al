namespace Demo.Library;

page 70333 "LIB Book Loan Ledger Entries"
{
    Caption = 'Book Loan Ledger Entries';
    PageType = List;
    SourceTable = "LIB Book Loan Ledger Entry";
    UsageCategory = Lists;
    ApplicationArea = All;
    Extensible = true;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field("Entry No."; Rec."Entry No.")
                {
                }
                field("Posting Date"; Rec."Posting Date")
                {
                }
                field("Document No."; Rec."Document No.")
                {
                }
                field("Book No."; Rec."Book No.")
                {
                }
                field("Member No."; Rec."Member No.")
                {
                }
                field("Entry Type"; Rec."Entry Type")
                {
                }
                field(Quantity; Rec.Quantity)
                {
                }
                field("Loan Date"; Rec."Loan Date")
                {
                }
                field("Due Date"; Rec."Due Date")
                {
                }
                field("Return Date"; Rec."Return Date")
                {
                }
            }
        }
    }
}
