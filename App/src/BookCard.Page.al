namespace Demo.Library;

page 70324 "LIB Book Card"
{
    Caption = 'Book Card';
    PageType = Card;
    SourceTable = "LIB Book";
    UsageCategory = None;
    Extensible = true;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';

                field("No."; Rec."No.")
                {
                    trigger OnAssistEdit()
                    begin
                        if Rec.AssistEdit(xRec) then
                            CurrPage.Update();
                    end;
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
                field(Description; Rec.Description)
                {
                    MultiLine = true;
                }
            }
            group(Inventory)
            {
                Caption = 'Inventory';

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
