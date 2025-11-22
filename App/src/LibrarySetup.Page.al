namespace Demo.Library;

page 70320 "LIB Library Setup"
{
    Caption = 'Library Setup';
    PageType = Card;
    SourceTable = "LIB Library Setup";
    InsertAllowed = false;
    DeleteAllowed = false;
    UsageCategory = Administration;
    ApplicationArea = All;
    Extensible = true;

    layout
    {
        area(Content)
        {
            group(Numbering)
            {
                Caption = 'Numbering';

                field("Author Nos."; Rec."Author Nos.")
                {
                    trigger OnValidate()
                    begin
                        CurrPage.Update();
                    end;
                }
                field("Book Nos."; Rec."Book Nos.")
                {
                    trigger OnValidate()
                    begin
                        CurrPage.Update();
                    end;
                }
                field("Member Nos."; Rec."Member Nos.")
                {
                    trigger OnValidate()
                    begin
                        CurrPage.Update();
                    end;
                }
                field("Book Loan Nos."; Rec."Book Loan Nos.")
                {
                    trigger OnValidate()
                    begin
                        CurrPage.Update();
                    end;
                }
                field("Posted Book Loan Nos."; Rec."Posted Book Loan Nos.")
                {
                    trigger OnValidate()
                    begin
                        CurrPage.Update();
                    end;
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.Reset();
        if not Rec.Get() then begin
            Rec.Init();
            Rec."Primary Key" := '';
            Rec.Insert(true);
        end;
    end;
}
