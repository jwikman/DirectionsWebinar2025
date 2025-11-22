table 70301 "LIB Author"
{
    Caption = 'Author';
    DataClassification = CustomerContent;
    DataPerCompany = true;
    Extensible = true;
    Access = Public;
    LookupPageId = "LIB Author List";
    DrillDownPageId = "LIB Author List";

    fields
    {
        field(1; "No."; Code[20])
        {
            Caption = 'No.';
            ToolTip = 'Specifies the unique identifier for the author.';
            DataClassification = CustomerContent;

            trigger OnValidate()
            var
                LibrarySetup: Record "LIB Library Setup";
                NoSeries: Codeunit "No. Series";
            begin
                if "No." <> xRec."No." then begin
                    LibrarySetup.Get();
                    NoSeries.TestManual(LibrarySetup."Author Nos.");
                    "No. Series" := '';
                end;
            end;
        }
        field(2; Name; Text[100])
        {
            Caption = 'Name';
            ToolTip = 'Specifies the name of the author.';
            DataClassification = CustomerContent;
        }
        field(3; Country; Text[50])
        {
            Caption = 'Country';
            ToolTip = 'Specifies the country of the author.';
            DataClassification = CustomerContent;
        }
        field(4; Biography; Text[250])
        {
            Caption = 'Biography';
            ToolTip = 'Specifies a brief biography of the author.';
            DataClassification = CustomerContent;
        }
        field(5; ISNI; Code[16])
        {
            Caption = 'ISNI';
            ToolTip = 'Specifies the International Standard Name Identifier (16 digits).';
            DataClassification = CustomerContent;

            trigger OnValidate()
            var
                InvalidISNIFormatErr: Label 'ISNI must be exactly 16 digits.';
                i: Integer;
            begin
                if ISNI = '' then
                    exit;

                if StrLen(ISNI) <> 16 then
                    Error(InvalidISNIFormatErr);

                for i := 1 to StrLen(ISNI) do
                    if not (ISNI[i] in ['0' .. '9']) then
                        Error(InvalidISNIFormatErr);
            end;
        }
        field(6; ORCID; Code[19])
        {
            Caption = 'ORCID';
            ToolTip = 'Specifies the Open Researcher and Contributor ID in format: 0000-0000-0000-0000.';
            DataClassification = CustomerContent;

            trigger OnValidate()
            var
                InvalidFormatErr: Label 'ORCID must be in format: 0000-0000-0000-0000 (four groups of four digits separated by hyphens).';
                i: Integer;
            begin
                if ORCID = '' then
                    exit;

                if StrLen(ORCID) <> 19 then
                    Error(InvalidFormatErr);

                // Check format: ####-####-####-####
                for i := 1 to StrLen(ORCID) do begin
                    if i in [5, 10, 15] then begin
                        if ORCID[i] <> '-' then
                            Error(InvalidFormatErr);
                    end else begin
                        if not (ORCID[i] in ['0' .. '9']) then
                            Error(InvalidFormatErr);
                    end;
                end;
            end;
        }
        field(7; "VIAF ID"; Code[20])
        {
            Caption = 'VIAF ID';
            ToolTip = 'Specifies the Virtual International Authority File identifier.';
            DataClassification = CustomerContent;
        }
        field(10; "No. Series"; Code[20])
        {
            Caption = 'No. Series';
            ToolTip = 'Specifies the number series from which the author number was assigned.';
            TableRelation = "No. Series";
            DataClassification = CustomerContent;
            Editable = false;
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
        fieldgroup(DropDown; "No.", Name, Country)
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
            LibrarySetup.TestField("Author Nos.");
            "No. Series" := LibrarySetup."Author Nos.";
            "No." := NoSeries.GetNextNo(LibrarySetup."Author Nos.");
        end;
    end;

    procedure AssistEdit(OldAuthor: Record "LIB Author"): Boolean
    var
        LibrarySetup: Record "LIB Library Setup";
        NoSeries: Codeunit "No. Series";
    begin
        LibrarySetup.Get();
        LibrarySetup.TestField("Author Nos.");
        if NoSeries.LookupRelatedNoSeries(LibrarySetup."Author Nos.", OldAuthor."No. Series", "No. Series") then begin
            "No." := NoSeries.GetNextNo("No. Series");
            exit(true);
        end;
    end;
}
