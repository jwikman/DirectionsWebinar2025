namespace Demo.Library;

page 70322 "LIB Author List"
{
    Caption = 'Authors';
    PageType = List;
    SourceTable = "LIB Author";
    CardPageId = "LIB Author Card";
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
                field(Name; Rec.Name)
                {
                }
                field(Country; Rec.Country)
                {
                }
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
