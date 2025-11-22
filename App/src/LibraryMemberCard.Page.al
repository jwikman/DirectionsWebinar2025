page 70326 "LIB Library Member Card"
{
    Caption = 'Library Member Card';
    PageType = Card;
    SourceTable = "LIB Library Member";
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
                    ToolTip = 'Specifies the unique identifier for the library member.';

                    trigger OnAssistEdit()
                    begin
                        if Rec.AssistEdit(xRec) then
                            CurrPage.Update();
                    end;
                }
                field(Name; Rec.Name)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the name of the library member.';
                }
                field("Membership Type"; Rec."Membership Type")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the type of membership (Regular, Student, or Senior).';
                }
                field("Member Since"; Rec."Member Since")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the date when the member joined the library.';
                }
                field(Active; Rec.Active)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether the library member is active.';
                }
            }
            group(Contact)
            {
                Caption = 'Contact';

                field(Email; Rec.Email)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the email address of the library member.';
                }
                field("Phone No."; Rec."Phone No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the phone number of the library member.';
                }
                field(Address; Rec.Address)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the address of the library member.';
                }
                field(City; Rec.City)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the city of the library member.';
                }
                field("Post Code"; Rec."Post Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the postal code of the library member.';
                }
            }
        }
    }
}
