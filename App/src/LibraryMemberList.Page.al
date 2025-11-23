namespace Demo.Library;

page 70327 "LIB Library Member List"
{
    Caption = 'Library Members';
    PageType = List;
    SourceTable = "LIB Library Member";
    CardPageId = "LIB Library Member Card";
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
                field(Email; Rec.Email)
                {
                }
                field("Phone No."; Rec."Phone No.")
                {
                }
                field("Membership Type"; Rec."Membership Type")
                {
                }
                field("Member Since"; Rec."Member Since")
                {
                }
                field(Active; Rec.Active)
                {
                }
            }
        }
    }
}
