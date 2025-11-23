namespace Demo.Library;

page 70329 "LIB Book Loan List"
{
    Caption = 'Book Loans';
    PageType = List;
    SourceTable = "LIB Book Loan Header";
    CardPageId = "LIB Book Loan";
    UsageCategory = Lists;
    ApplicationArea = All;
    Extensible = true;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
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
                field(Status; Rec.Status)
                {
                }
                field("No. of Lines"; Rec."No. of Lines")
                {
                }
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
