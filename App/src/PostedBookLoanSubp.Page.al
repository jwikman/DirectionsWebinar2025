namespace Demo.Library;

page 70334 "LIB Posted Book Loan Subp."
{
    Caption = 'Lines';
    PageType = ListPart;
    SourceTable = "LIB Posted Book Loan Line";
    Extensible = true;
    Editable = false;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field("Book No."; Rec."Book No.")
                {
                }
                field("Book Title"; Rec."Book Title")
                {
                }
                field(Quantity; Rec.Quantity)
                {
                }
                field("Due Date"; Rec."Due Date")
                {
                }
            }
        }
    }
}
