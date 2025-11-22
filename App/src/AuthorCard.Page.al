namespace Demo.Library;

page 70321 "LIB Author Card"
{
    Caption = 'Author Card';
    PageType = Card;
    SourceTable = "LIB Author";
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
                field(Name; Rec.Name)
                {
                    ApplicationArea = All;
                }
                field(Country; Rec.Country)
                {
                    ApplicationArea = All;
                }
                field(Biography; Rec.Biography)
                {
                    ApplicationArea = All;
                    MultiLine = true;
                }
            }
            group(Identifiers)
            {
                Caption = 'Identifiers';

                field(ISNI; Rec.ISNI)
                {
                    ApplicationArea = All;
                }
                field(ORCID; Rec.ORCID)
                {
                    ApplicationArea = All;
#pragma warning restore AA0240
                }
                field("VIAF ID"; Rec."VIAF ID")
                {
                    ApplicationArea = All;
                }
            }
        }
    }
}
