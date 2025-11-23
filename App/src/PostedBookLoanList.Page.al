namespace Demo.Library;

page 70332 "LIB Posted Book Loan List"
{
    Caption = 'Posted Book Loans';
    PageType = List;
    SourceTable = "LIB Posted Book Loan Header";
    CardPageId = "LIB Posted Book Loan Card";
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
                field("Posting Date"; Rec."Posting Date")
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
            action(Return)
            {
                Caption = 'Return';
                ToolTip = 'Process the return of the loaned books.';
                Image = Return;
                Promoted = true;
                PromotedCategory = Process;
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
