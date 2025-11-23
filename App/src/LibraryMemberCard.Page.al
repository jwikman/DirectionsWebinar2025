namespace Demo.Library;

page 70326 "LIB Library Member Card"
{
    Caption = 'Library Member Card';
    PageType = Card;
    SourceTable = "LIB Library Member";
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
            group(Contact)
            {
                Caption = 'Contact';

                field(Email; Rec.Email)
                {
                }
                field("Phone No."; Rec."Phone No.")
                {
                }
                field(Address; Rec.Address)
                {
                }
                field(City; Rec.City)
                {
                }
                field("Post Code"; Rec."Post Code")
                {
                }
            }
        }
    }
}
