namespace Demo.Library;

page 70324 "LIB Book Card"
{
    Caption = 'Book Card';
    PageType = Card;
    SourceTable = "LIB Book";
    UsageCategory = None;
    Extensible = true;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';

                field("No."; Rec."No.")
                {
                    ApplicationArea = All;
                    trigger OnAssistEdit()
                    begin
                        if Rec.AssistEdit(xRec) then
                            CurrPage.Update();
                    end;
                }
                field(Title; Rec.Title)
                {
                    ApplicationArea = All;
                }
                field("Author No."; Rec."Author No.")
                {
                    ApplicationArea = All;
                }
                field(ISBN; Rec.ISBN)
                {
                    ApplicationArea = All;
                }
                field("Genre Code"; Rec."Genre Code")
                {
                    ApplicationArea = All;
                }
                field("Publication Year"; Rec."Publication Year")
                {
                    ApplicationArea = All;
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    MultiLine = true;
                }
            }
            group(Inventory)
            {
                Caption = 'Inventory';

                field(Quantity; Rec.Quantity)
                {
                    ApplicationArea = All;
                }
                field("Available Quantity"; Rec."Available Quantity")
                {
                    ApplicationArea = All;
                }
            }
        }
    }
}
