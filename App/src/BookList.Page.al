namespace Demo.Library;

page 70325 "LIB Book List"
{
    Caption = 'Books';
    PageType = List;
    SourceTable = "LIB Book";
    CardPageId = "LIB Book Card";
    UsageCategory = Lists;
    ApplicationArea = All;
    Extensible = true;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field("No."; Rec."No.")
                {
                }
                field(Title; Rec.Title)
                {
                }
                field("Author No."; Rec."Author No.")
                {
                }
                field(ISBN; Rec.ISBN)
                {
                }
                field("Genre Code"; Rec."Genre Code")
                {
                }
                field("Publication Year"; Rec."Publication Year")
                {
                }
                field(Quantity; Rec.Quantity)
                {
                }
                field("Available Quantity"; Rec."Available Quantity")
                {
                }
            }
        }
    }
}
