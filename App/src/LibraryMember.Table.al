namespace Demo.Library;

using Microsoft.Foundation.NoSeries;

table 70304 "LIB Library Member"
{
    Caption = 'Library Member';
    DataClassification = CustomerContent;
    DataPerCompany = true;
    Extensible = true;
    Access = Public;
    LookupPageId = "LIB Library Member List";
    DrillDownPageId = "LIB Library Member List";

    fields
    {
        field(1; "No."; Code[20])
        {
            Caption = 'No.';
            ToolTip = 'Specifies the unique identifier for the library member.';

            trigger OnValidate()
            var
                LibrarySetup: Record "LIB Library Setup";
                NoSeries: Codeunit "No. Series";
            begin
                if "No." <> xRec."No." then begin
                    LibrarySetup.Get();
                    NoSeries.TestManual(LibrarySetup."Member Nos.");
                    "No. Series" := '';
                end;
            end;
        }
        field(2; Name; Text[100])
        {
            Caption = 'Name';
            ToolTip = 'Specifies the name of the library member.';
        }
        field(3; Email; Text[80])
        {
            Caption = 'Email';
            ToolTip = 'Specifies the email address of the library member.';
            ExtendedDatatype = EMail;

            trigger OnValidate()
            var
                InvalidEmailErr: Label 'The email address is not valid.';
            begin
                if Email = '' then
                    exit;

                if not Email.Contains('@') then
                    Error(InvalidEmailErr);
            end;
        }
        field(4; "Phone No."; Text[30])
        {
            Caption = 'Phone No.';
            ToolTip = 'Specifies the phone number of the library member.';
            ExtendedDatatype = PhoneNo;
        }
        field(5; Address; Text[100])
        {
            Caption = 'Address';
            ToolTip = 'Specifies the address of the library member.';
        }
        field(6; City; Text[30])
        {
            Caption = 'City';
            ToolTip = 'Specifies the city of the library member.';
        }
        field(7; "Post Code"; Code[20])
        {
            Caption = 'Post Code';
            ToolTip = 'Specifies the postal code of the library member.';
        }
        field(8; "Membership Type"; Enum "LIB Membership Type")
        {
            Caption = 'Membership Type';
            ToolTip = 'Specifies the type of membership (Regular, Student, or Senior).';
        }
        field(9; "Member Since"; Date)
        {
            Caption = 'Member Since';
            ToolTip = 'Specifies the date when the member joined the library.';
        }
        field(10; Active; Boolean)
        {
            Caption = 'Active';
            ToolTip = 'Specifies whether the library member is active.';
            InitValue = true;
        }
        field(11; "No. Series"; Code[20])
        {
            Caption = 'No. Series';
            ToolTip = 'Specifies the number series from which the member number was assigned.';
            TableRelation = "No. Series";
            Editable = false;
            AllowInCustomizations = Never;
        }
    }

    keys
    {
        key(Key1; "No.")
        {
            Clustered = true;
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "No.", Name, Email)
        {
        }
        fieldgroup(Brick; "No.", Name, "Membership Type")
        {
        }
    }

    trigger OnInsert()
    var
        LibrarySetup: Record "LIB Library Setup";
        NoSeries: Codeunit "No. Series";
    begin
        if "No." = '' then begin
            LibrarySetup.Get();
            LibrarySetup.TestField("Member Nos.");
            "No. Series" := LibrarySetup."Member Nos.";
            "No." := NoSeries.GetNextNo(LibrarySetup."Member Nos.");
        end;

        if "Member Since" = 0D then
            "Member Since" := Today();
    end;

    /// <summary>
    /// Enables the user to select a number series for the library member.
    /// </summary>
    /// <param name="OldMember">The previous member record state.</param>
    /// <returns>True if a number series was selected; otherwise, false.</returns>
    procedure AssistEdit(OldMember: Record "LIB Library Member"): Boolean
    var
        LibrarySetup: Record "LIB Library Setup";
        NoSeries: Codeunit "No. Series";
    begin
        LibrarySetup.Get();
        LibrarySetup.TestField("Member Nos.");
        if NoSeries.LookupRelatedNoSeries(LibrarySetup."Member Nos.", OldMember."No. Series", "No. Series") then begin
            "No." := NoSeries.GetNextNo("No. Series");
            exit(true);
        end;
    end;
}
