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
                    ToolTip = 'Specifies the unique identifier for the library member.';
                }
                field(Name; Rec.Name)
                {
                    ToolTip = 'Specifies the name of the library member.';
                }
                field(Email; Rec.Email)
                {
                    ToolTip = 'Specifies the email address of the library member.';
                }
                field("Phone No."; Rec."Phone No.")
                {
                    ToolTip = 'Specifies the phone number of the library member.';
                }
                field("Membership Type"; Rec."Membership Type")
                {
                    ToolTip = 'Specifies the type of membership (Regular, Student, or Senior).';
                }
                field("Member Since"; Rec."Member Since")
                {
                    ToolTip = 'Specifies the date when the member joined the library.';
                }
                field(Active; Rec.Active)
                {
                    ToolTip = 'Specifies whether the library member is active.';
                }
            }
        }
    }
}
