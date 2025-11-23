namespace Demo.Library;

page 70330 "LIB Book Loan Subpage"
{
    Caption = 'Lines';
    PageType = ListPart;
    SourceTable = "LIB Book Loan Line";
    AutoSplitKey = true;
    Extensible = true;
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
