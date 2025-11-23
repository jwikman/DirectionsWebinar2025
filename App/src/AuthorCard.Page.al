namespace Demo.Library;

page 70321 "LIB Author Card"
{
    Caption = 'Author Card';
    PageType = Card;
    SourceTable = "LIB Author";
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
                field(Name; Rec.Name)
                {
                }
                field(Country; Rec.Country)
                {
                }
                field(Biography; Rec.Biography)
                {
                    MultiLine = true;
                }
            }
            group(Identifiers)
            {
                Caption = 'Identifiers';

                field(ISNI; Rec.ISNI)
                {
                }
                field(ORCID; Rec.ORCID)
                {
#pragma warning restore AA0240
                }
                field("VIAF ID"; Rec."VIAF ID")
                {
                }
            }
        }
    }
}
