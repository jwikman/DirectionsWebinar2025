namespace Demo.Library;

page 70331 "LIB Posted Book Loan Card"
{
    Caption = 'Posted Book Loan';
    PageType = Card;
    SourceTable = "LIB Posted Book Loan Header";
    UsageCategory = None;
    Extensible = true;
    Editable = false;
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
                }
                field("Member No."; Rec."Member No.")
                {
                }
                field("Member Name"; Rec."Member Name")
                {
                }
                field("Loan Date"; Rec."Loan Date")
                {
                }
                field("Expected Return Date"; Rec."Expected Return Date")
                {
                }
                field("Posting Date"; Rec."Posting Date")
                {
                }
            }
            part(Lines; "LIB Posted Book Loan Subp.")
            {
                SubPageLink = "Document No." = field("No.");
            }
        }
        area(FactBoxes)
        {
            systempart(Links; Links)
            {
            }
            systempart(Notes; Notes)
            {
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Return)
            {
                Caption = 'Return';
                ToolTip = 'Process the return of the loaned books.';
                Image = Return;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                PromotedOnly = true;

                trigger OnAction()
                var
                    BookReturnPostYesNo: Codeunit "LIB Book Return-Post (Yes/No)";
                begin
                    BookReturnPostYesNo.Run(Rec);
                end;
            }
        }
    }
}
