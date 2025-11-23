namespace Demo.Library;

page 70323 "LIB Genre List"
{
    Caption = 'Genres';
    PageType = List;
    SourceTable = "LIB Genre";
    UsageCategory = Lists;
    ApplicationArea = All;
    Extensible = true;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field(Code; Rec.Code)
                {
                }
                field(Description; Rec.Description)
                {
                }
            }
        }
    }
}
