namespace Demo.Library;

page 70328 "LIB Book Loan"
{
    Caption = 'Book Loan';
    PageType = Document;
    SourceTable = "LIB Book Loan Header";
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
                field(Status; Rec.Status)
                {
                }
            }
            part(Lines; "LIB Book Loan Subpage")
            {
                SubPageLink = "Document No." = field("No.");
                UpdatePropagation = Both;
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
            action(Post)
            {
                Caption = 'Post';
                ToolTip = 'Post the book loan.';
                Image = Post;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                PromotedOnly = true;

                trigger OnAction()
                var
                    BookLoanPostYesNo: Codeunit "LIB Book Loan-Post (Yes/No)";
                begin
                    BookLoanPostYesNo.Run(Rec);
                end;
            }
        }
    }
}
