$date_time = Get-Date -Format yyyyMMddHHmm
$output_file = "./support.cdc.vaccine.update." + $date_time + ".sql"
$zip_path = "."

$script_header = @"
/*

   [11.17.2021]
      Update cvx/cdc/vaccine data

      Note, this script is a one time run only, intended for assisting the support department with updates to the vaccines.
      ALL data is provided from the data sources below. This scripts doesn't facilitate adding a single code unless you manually update the data contained in the file

   [Data Sources]
      cvx              http://www2a.cdc.gov/vaccines/iis/iisstandards/downloads/cvx.txt
      cvxvis           http://www2a.cdc.gov/vaccines/iis/iisstandards/downloads/cvx_vis.txt
      vg               http://www2a.cdc.gov/vaccines/iis/iisstandards/downloads/VG.txt
      tradename        http://www2a.cdc.gov/vaccines/iis/iisstandards/downloads/TRADENAME.txt 
      visbarcodelookup https://www2a.cdc.gov/vaccines/iis/iisstandards/downloads/vis-barcode-lookup.txt 
      mvx              http://www2a.cdc.gov/vaccines/iis/iisstandards/downloads/mvx.txt

*/

set nocount on;

if not exists(select * from sys.tables where name = 'archiveclcvx')
begin
   create table dbo.[archiveclcvx] 
   (
      cvx       int, 
      shortdesc varchar(100), 
      archivedt datetime, 
      constraint pk_archiveclcvx primary key (cvx, archivedt)
   )
end
go 

 if not exists(select * from sys.tables where name = 'archiveclvaccineproduct')
begin
   create table dbo.[archiveclvaccineproduct]
   (
        cvx        INT          NOT NULL,
        mvx        VARCHAR(3)   NOT NULL,
        cdcname    VARCHAR(100) NOT NULL, 
        active     CHAR(1)      NOT NULL,
        updatedate DATETIME     NOT NULL, 
        archivedt  DATETIME     NOT NULL,
        CONSTRAINT pk_archiveclvaccineproduct PRIMARY KEY CLUSTERED (cvx, mvx, cdcname, active, updatedate, archivedt)
    )
end
go 

if not exists(select * from sys.tables where name = 'archiveclvishandout')
begin
    create table dbo.[archiveclvishandout]
    (
        cvx           INT          NOT NULL, 
        handoutid     INT          NOT NULL,
        documentname  VARCHAR(100) NOT NULL,
        editiondate   DATETIME     NOT NULL,
        editionactive CHAR(1)      NOT NULL,
        genericcvx    INT          NULL, 
        archivedt     DATETIME     NOT NULL,
        CONSTRAINT [pk_archiveclvishandout] PRIMARY KEY CLUSTERED (handoutid, archivedt)
    )
end
go

-- these temp tables will be populated by all of the source data contained in this script
declare @cvx table (
    [cvxcode]         [numeric](10, 0) NULL,
    [shortdesc]       [varchar](250)   NULL,
    [fullvaccinename] [varchar](250)   NULL,
    [notes]           [varchar](500)   NULL,
    [vaccinestatus]   [varchar](50)    NULL,
    [lastupdatedate]  [datetime]       NULL
);  
 
declare @cvx_vis table(
    [cvxcode]             [numeric](10, 0) NULL,
    [cvxvaccinedesc]      [varchar](250)   NULL,
    [visfullenctxtstring] [numeric](30, 0) NULL,
    [visdocumentname]     [varchar](250)   NULL,
    [viseditiondate]      [date]           NULL,
    [viseditionstatus]    [varchar](50)    NULL,
  [cvxforvaccinegroup]  int              NULL
); 

declare @tradename table(
    [cdcprodname]    [varchar](250)   NULL,
    [shortdesc]      [varchar](250)   NULL,
    [cvxcode]        [numeric](10, 0) NULL,
    [manufacturer]   [varchar](150)   NULL,
    [mvxcode]        [varchar](10)    NULL,
    [mvxstatus]      [varchar](50)    NULL,
    [prodnamestatus] [varchar](50)    NULL,
    [lastupdatedate] [date]           NULL
); 
 
declare @vg table (
    [shortdesc]          [varchar](250)   NULL,
    [cvxcode]            [numeric](10, 0) NULL,
    [vaccinestatus]      [varchar](50)    NULL,
    [vaccinegroupname]   [varchar](250)   NULL,
    [cvxforvaccinegroup] [numeric](10, 0) NULL
); 

BEGIN
"@

Add-Content -Path $output_file -value $script_header

Add-Content -Path $output_file -value "`n"

# Import and Scrub Files
$cvx_path = $zip_path + "/cvx.txt"
$cvx_header = "CVX Code", "Short Description", "Full Vaccine name", "Notes", `
          "Vaccine Status", "Nonvaccine", "Last Updated Date"
$cvx =  Import-Csv -Path $cvx_path -Header $cvx_header -Delimiter "|" | 
        Select-Object -Property "CVX Code", "Short Description", `
          "Full Vaccine name", "Vaccine Status", `
          @{name="Notes";expression={$_."Notes" -replace "'","''"}}, `
          @{name="Last Updated Date";expression={$_."Last Updated Date" -replace "/","-"}}
$cvx | ForEach-Object { 
  $_."CVX Code" = $_."CVX Code".Trim() 
  $_."CVX Code" = $_."CVX Code".TrimStart("0")
  $_."Short Description" = $_."Short Description".Trim()
  $_."Full Vaccine name" = $_."Full Vaccine name".Trim()
  $_."Notes" = $_."Notes".Trim()
  $_."Vaccine Status" = $_."Vaccine Status".Trim()
  $_."Last Updated Date" = $_."Last Updated Date".Trim()
}

$tradename_path = $zip_path + "/TRADENAME.txt"
$tradename_header = "CDC Product Name", "Short Description", "CVX Code", "Manufacturer", `
          "MVX Code", "MVX status", "Product name status", "Last Updated Date"
$tradename =  Import-Csv -Path $tradename_path -Header $tradename_header -Delimiter "|" 
$tradename | ForEach-Object { 
  $_."CDC Product Name" = $_."CDC Product Name".Trim() 
  $_."Short Description" = $_."Short Description".Trim()
  $_."CVX Code" = $_."CVX Code".Trim()
  $_."Manufacturer" = $_."Manufacturer".Trim()
  $_."MVX Code" = $_."MVX Code".Trim()
  $_."MVX status" = $_."MVX status".Trim()
  $_."Product name status" = $_."Product name status".Trim()
  $_."Last Updated Date" = $_."Last Updated Date".Trim()
}

$cvx_vis_path = $zip_path + "/cvx_vis.txt"
$cvx_vis_header = "CVX Code", "CVX Vaccine Description", "VIS Fully-encoded text string", "VIS Document Name", `
          "VIS Edition Date", "VIS Edition status"
$cvx_vis =  Import-Csv -Path $cvx_vis_path -Header $cvx_vis_header -Delimiter "|" | 
            Select-Object -Property "CVX Code", "CVX Vaccine Description", `
              "VIS Fully-encoded text string", "VIS Document Name", "VIS Edition status", `
              @{name="VIS Edition Date";expression={$_."VIS Edition Date" -replace " 00:00:00",""}} |
            Where-Object { $_."VIS Edition status" -eq "Current" }
$cvx_vis | ForEach-Object { 
  $_."CVX Code" = $_."CVX Code".Trim() 
  $_."CVX Code" = $_."CVX Code".TrimStart("0") 
  $_."CVX Vaccine Description" = $_."CVX Vaccine Description".Trim()
  $_."VIS Fully-encoded text string" = $_."VIS Fully-encoded text string".Trim()
  $_."VIS Document Name" = $_."VIS Document Name".Trim()
  $_."VIS Edition status" = $_."VIS Edition status".Trim()
  $_."VIS Edition Date" = $_."VIS Edition Date".Trim()
}

$vg_path = $zip_path + "/VG.txt"
$vg_header = "Short Description", "CVX Code", "Vaccine status", `
          "Vaccine Group Name", "CVX for Vaccine Group"
$vg =  Import-Csv -Path $vg_path -Header $vg_header -Delimiter "|" 

$vg | ForEach-Object { 
  $_."Short Description" = $_."Short Description".Trim()
  $_."CVX Code" = $_."CVX Code".Trim()
  $_."CVX Code" = $_."CVX Code".TrimStart("0") 
  $_."Vaccine status" = $_."Vaccine status".Trim()
  $_."Vaccine Group Name" = $_."Vaccine Group Name".Trim()
  $_."CVX for Vaccine Group" = $_."CVX for Vaccine Group".Trim()
  $_."CVX for Vaccine Group" = $_."CVX for Vaccine Group".TrimStart("0") 
}

# Assign CVX for Vaccine Group to VIS Document Name with Pattern Matching
$cvx_vis |  Where-Object { $_."VIS Document Name" -eq "Polio Vaccine VIS" } |
            Add-Member -Force -NotePropertyName "CVX for Vaccine Group" -NotePropertyValue 89
$cvx_vis |  Where-Object { $_."VIS Document Name" -eq "Typhoid VIS" } |
            Add-Member -Force -NotePropertyName "CVX for Vaccine Group" -NotePropertyValue 91
$cvx_vis |  Where-Object { $_."VIS Document Name" -eq "Hepatitis A Vaccine VIS" } |
            Add-Member -Force -NotePropertyName "CVX for Vaccine Group" -NotePropertyValue 85
$cvx_vis |  Where-Object { $_."VIS Document Name" -eq "Hepatitis B Vaccine VIS" } |
            Add-Member -Force -NotePropertyName "CVX for Vaccine Group" -NotePropertyValue 45
$cvx_vis |  Where-Object { $_."VIS Document Name" -like "*Diphtheria*Tetanus*Pertussis*" } |
            Add-Member -Force -NotePropertyName "CVX for Vaccine Group" -NotePropertyValue 107
$cvx_vis |  Where-Object { $_."VIS Document Name" -like "*Influenza*" } |
            Add-Member -Force -NotePropertyName "CVX for Vaccine Group" -NotePropertyValue 88
$cvx_vis |  Where-Object { $_."VIS Document Name" -like "*Tetanus*Diphtheria*Td*VIS*" } |
            Add-Member -Force -NotePropertyName "CVX for Vaccine Group" -NotePropertyValue 139
$cvx_vis |  Where-Object { $_."VIS Document Name" -like "*Td*Tetanus*Diphtheria*VIS*" } |
            Add-Member -Force -NotePropertyName "CVX for Vaccine Group" -NotePropertyValue 139
$cvx_vis |  Where-Object { $_."VIS Document Name" -like "Meningococcal ACWY*VIS" } |
            Add-Member -Force -NotePropertyName "CVX for Vaccine Group" -NotePropertyValue 108
$cvx_vis |  Where-Object { $_."VIS Document Name" -like "*Tetanus*Diphtheria*Pertussis*" } |
            Add-Member -Force -NotePropertyName "CVX for Vaccine Group" -NotePropertyValue 115
$cvx_vis |  Where-Object { $_."VIS Document Name" -like "Rotavirus*VIS" } |
            Add-Member -Force -NotePropertyName "CVX for Vaccine Group" -NotePropertyValue 122
$cvx_vis |  Where-Object { $_."VIS Document Name" -eq "Human papillomavirus Vaccine (Cervarix) VIS" } |
            Add-Member -Force -NotePropertyName "CVX for Vaccine Group" -NotePropertyValue 137
$cvx_vis |  Where-Object { $_."VIS Document Name" -like "H*i*b*VIS" } |
            Add-Member -Force -NotePropertyName "CVX for Vaccine Group" -NotePropertyValue 17
$cvx_vis |  Where-Object { $_."VIS Document Name" -like "*Zoster*VIS" -OR $_."VIS Document Name" -like "*Shingles*VIS" } |
            Add-Member -Force -NotePropertyName "CVX for Vaccine Group" -NotePropertyValue 121
$cvx_vis |  Where-Object { $_."VIS Document Name" -like "PCV13*VIS" } |
            Add-Member -Force -NotePropertyName "CVX for Vaccine Group" -NotePropertyValue 152
$cvx_vis |  Where-Object { $_."VIS Document Name" -like "Japanese Encephalitis*VIS" } |
            Add-Member -Force -NotePropertyName "CVX for Vaccine Group" -NotePropertyValue 129
$cvx_vis |  Where-Object { $_."VIS Document Name" -like "Adenovirus*VIS" } |
            Add-Member -Force -NotePropertyName "CVX for Vaccine Group" -NotePropertyValue 82
$cvx_vis |  Where-Object { $_."VIS Document Name" -like "*B*" -AND $_."VIS Document Name" -like "*Meningococcal*" -AND $_."VIS Document Name" -like "*VIS*" } |
            Add-Member -Force -NotePropertyName "CVX for Vaccine Group" -NotePropertyValue 164
$cvx_vis |  Where-Object { $_."VIS Document Name" -like "*HPV*Vaccine*VIS" } |
            Add-Member -Force -NotePropertyName "CVX for Vaccine Group" -NotePropertyValue 137
$cvx_vis |  Where-Object { $_."VIS Document Name" -eq "Rabies VIS" } |
            Add-Member -Force -NotePropertyName "CVX for Vaccine Group" -NotePropertyValue 90
$cvx_vis |  Where-Object { $_."VIS Document Name" -like "Varicella*VIS" } |
            Add-Member -Force -NotePropertyName "CVX for Vaccine Group" -NotePropertyValue 21
$cvx_vis |  Where-Object { $_."VIS Document Name" -like "Anthrax*VIS" } |
            Add-Member -Force -NotePropertyName "CVX for Vaccine Group" -NotePropertyValue 24
$cvx_vis |  Where-Object { $_."VIS Document Name" -like "M*M*R*VIS" } |
            Add-Member -Force -NotePropertyName "CVX for Vaccine Group" -NotePropertyValue 3
$cvx_vis |  Where-Object { $_."VIS Document Name" -like "P*P*VIS" } |
            Add-Member -Force -NotePropertyName "CVX for Vaccine Group" -NotePropertyValue 33
$cvx_vis |  Where-Object { $_."VIS Document Name" -eq "Yellow Fever VIS" } |
            Add-Member -Force -NotePropertyName "CVX for Vaccine Group" -NotePropertyValue 184
$cvx_vis |  Where-Object { $_."VIS Document Name" -eq "Human papillomavirus Vaccine (Gardasil) VIS" } |
            Add-Member -Force -NotePropertyName "CVX for Vaccine Group" -NotePropertyValue 137
$cvx_vis |  Where-Object { $_."VIS Document Name" -like "M*M*R*V*VIS" } |
            Add-Member -Force -NotePropertyName "CVX for Vaccine Group" -NotePropertyValue 3
$cvx_vis |  Where-Object { $_."VIS Document Name" -like "Hepatitis B*VIS" } |
            Add-Member -Force -NotePropertyName "CVX for Vaccine Group" -NotePropertyValue 45
$cvx_vis |  Where-Object { $_."VIS Document Name" -like "Rabies*VIS" } |
            Add-Member -Force -NotePropertyName "CVX for Vaccine Group" -NotePropertyValue 90
$cvx_vis |  Where-Object { $_."VIS Document Name" -like "Cholera*VIS" } |
            Add-Member -Force -NotePropertyName "CVX for Vaccine Group" -NotePropertyValue 26
$cvx_vis |  Where-Object { $_."VIS Document Name" -like "Recombinant Zoster*VIS" } |
            Add-Member -Force -NotePropertyName "CVX for Vaccine Group" -NotePropertyValue 188
$cvx_vis |  Where-Object { $_."VIS Document Name" -like "COVID-19*" } |
            Add-Member -Force -NotePropertyName "CVX for Vaccine Group" -NotePropertyValue 213

# Assign CVX for Vaccine Group to VIS Document Name for Multi VIS Codes
$cvx_vis |  Where-Object { $_."CVX Code" -eq 10 -AND $_."VIS Document Name" -eq "Multi Pediatric Vaccines VIS" } |
            Add-Member -Force -NotePropertyName "CVX for Vaccine Group" -NotePropertyValue 89
$cvx_vis |  Where-Object { $_."CVX Code" -eq 110 -AND $_."VIS Document Name" -eq "Multi Pediatric Vaccines VIS" } |
            Add-Member -Force -NotePropertyName "CVX for Vaccine Group" -NotePropertyValue "NULL"
$cvx_vis |  Where-Object { $_."CVX Code" -eq 106 -AND $_."VIS Document Name" -eq "Multi Pediatric Vaccines VIS" } |
            Add-Member -Force -NotePropertyName "CVX for Vaccine Group" -NotePropertyValue 107
$cvx_vis |  Where-Object { $_."CVX Code" -eq 116 -AND $_."VIS Document Name" -eq "Multi Pediatric Vaccines VIS" } |
            Add-Member -Force -NotePropertyName "CVX for Vaccine Group" -NotePropertyValue 122
$cvx_vis |  Where-Object { $_."CVX Code" -eq 119 -AND $_."VIS Document Name" -eq "Multi Pediatric Vaccines VIS" } |
            Add-Member -Force -NotePropertyName "CVX for Vaccine Group" -NotePropertyValue 122
$cvx_vis |  Where-Object { $_."CVX Code" -eq 120 -AND $_."VIS Document Name" -eq "Multi Pediatric Vaccines VIS" } |
            Add-Member -Force -NotePropertyName "CVX for Vaccine Group" -NotePropertyValue "NULL"
$cvx_vis |  Where-Object { $_."CVX Code" -eq 130 -AND $_."VIS Document Name" -eq "Multi Pediatric Vaccines VIS" } |
            Add-Member -Force -NotePropertyName "CVX for Vaccine Group" -NotePropertyValue "NULL"
$cvx_vis |  Where-Object { $_."CVX Code" -eq 133 -AND $_."VIS Document Name" -eq "Multi Pediatric Vaccines VIS" } |
            Add-Member -Force -NotePropertyName "CVX for Vaccine Group" -NotePropertyValue 152
$cvx_vis |  Where-Object { $_."CVX Code" -eq 146 -AND $_."VIS Document Name" -eq "Multi Pediatric Vaccines VIS" } |
            Add-Member -Force -NotePropertyName "CVX for Vaccine Group" -NotePropertyValue "NULL"
$cvx_vis |  Where-Object { $_."CVX Code" -eq 20 -AND $_."VIS Document Name" -eq "Multi Pediatric Vaccines VIS" } |
            Add-Member -Force -NotePropertyName "CVX for Vaccine Group" -NotePropertyValue 107
$cvx_vis |  Where-Object { $_."CVX Code" -eq 48 -AND $_."VIS Document Name" -eq "Multi Pediatric Vaccines VIS" } |
            Add-Member -Force -NotePropertyName "CVX for Vaccine Group" -NotePropertyValue 17
$cvx_vis |  Where-Object { $_."CVX Code" -eq 49 -AND $_."VIS Document Name" -eq "Multi Pediatric Vaccines VIS" } |
            Add-Member -Force -NotePropertyName "CVX for Vaccine Group" -NotePropertyValue 17
$cvx_vis |  Where-Object { $_."CVX Code" -eq 51 -AND $_."VIS Document Name" -eq "Multi Pediatric Vaccines VIS" } |
            Add-Member -Force -NotePropertyName "CVX for Vaccine Group" -NotePropertyValue "NULL"
$cvx_vis |  Where-Object { $_."CVX Code" -eq 8 -AND $_."VIS Document Name" -eq "Multi Pediatric Vaccines VIS" } |
            Add-Member -Force -NotePropertyName "CVX for Vaccine Group" -NotePropertyValue 0
$cvx_vis |  Where-Object { $_."CVX Code" -eq 28 -AND $_."VIS Document Name" -like "Multi Pediatric*VIS" } |
            Add-Member -Force -NotePropertyName "CVX for Vaccine Group" -NotePropertyValue 107

# Assign CVX for Vaccine Group to VIS Document Name for One-to-one Correlations
$vg_unique_cvx = $vg | Select-Object -Property "CVX Code" -Unique

$cvx_vis | ForEach-Object {
  if ($_."CVX for Vaccine Group" -eq $null) {
    if ($vg_unique_cvx."CVX Code" -contains $_."CVX Code") {
      $group_cvx_candidate = $vg | Where-Object -Property "CVX Code" -eq $_."CVX Code"
      $_ | Add-Member -Force -NotePropertyName "CVX for Vaccine Group" `
            -NotePropertyValue $group_cvx_candidate."CVX for Vaccine Group"
    }
  }
}

$cvx_vis | ForEach-Object {
  if ($_."CVX for Vaccine Group" -eq $null) { 
    throw "The following cvx_vis entry does not have a CVX for Vaccine Group code: " + $_ 
  }
}

# Generate Insert Statements
$cvx | ForEach-Object {
  Add-Content -Path $output_file -value (
    "INSERT @cvx ([cvxcode], [shortdesc], [fullvaccinename], [notes], [vaccinestatus], [lastupdatedate]) VALUES (" + `
    $_."CVX Code" + ",N'" + $_."Short Description" + "', N'" + $_."Full Vaccine name" +  "', N'" + `
    $_."Notes" + "', N'" + $_."Vaccine Status" + "', N'" + $_."Last Updated Date" + "T00:00:00.000' );"
  )
}

Add-Content -Path $output_file -value "`n"
 
$cvx_vis | ForEach-Object {
  Add-Content -Path $output_file -value (
    "INSERT @cvx_vis ([cvxcode], [cvxvaccinedesc], [visfullenctxtstring], [visdocumentname], [viseditiondate], [viseditionstatus], [cvxforvaccinegroup]) VALUES (CAST(" + `
    $_."CVX Code" + " AS Numeric(10, 0)), N'" + $_."CVX Vaccine Description" + "', CAST(" + $_."VIS Fully-encoded text string" +  " AS Numeric(30, 0)), N'" + `
    $_."VIS Document Name" + "', CAST(N'" + $_."VIS Edition Date" + "' AS Date), N'" + $_."VIS Edition status" + "', " + $_."CVX for Vaccine Group" + ");"
  )
}

Add-Content -Path $output_file -value "`n"

$tradename | ForEach-Object {
  Add-Content -Path $output_file -value (
    "INSERT @tradename ([cdcprodname], [shortdesc], [cvxcode], [manufacturer], [mvxcode], [mvxstatus], [prodnamestatus], [lastupdatedate]) VALUES (N'" + `
    $_."CDC Product Name" + "', N'" + $_."Short Description" + "', N'" + $_."CVX Code" +  "', N'" + $_."Manufacturer" + "', N'" + `
    $_."MVX Code" + "', N'" + $_."MVX status" + "', N'" + $_."Product name status" + "', N'" + $_."Last Updated Date" + "');"
  )
}

Add-Content -Path $output_file -value "`n"

$vg | ForEach-Object {
  Add-Content -Path $output_file -value (
    "INSERT @vg ([shortdesc], [cvxcode], [vaccinestatus], [vaccinegroupname], [cvxforvaccinegroup]) VALUES (N'" + `
    $_."Short Description" + "', " + $_."CVX Code" + ",N'" + $_."Vaccine status" +  "', N'" + `
    $_."Vaccine Group Name" + "', " + $_."CVX for Vaccine Group" + ");"
  )
}

Add-Content -Path $output_file -value "`n"

$script_footer = @"
END
 
-- set cvxforvaccinegroup values
update cvx_vis  
set cvxforvaccinegroup = (Select top 1 cvxforvaccinegroup 
                          from @vg vg 
              where vg.cvxcode = cvx_vis.cvxcode 
                 and vg.vaccinestatus in('Pending', 'Active'))
from @cvx_vis as cvx_vis
where viseditionstatus = 'Current'
   and cvx_vis.cvxforvaccinegroup is null
   and (select count(*) 
        from @vg vg 
        where vg.vaccinestatus in('Pending', 'Active') 
           and cvxcode = cvx_vis.cvxcode
        ) = 1

update @cvx_vis
set cvxforvaccinegroup = null
where cvxforvaccinegroup = 0;

-- [CLCVX] Archive And Insert/Delete
begin

   if exists(select * from dbo.CLCVX)
   begin
      insert into dbo.archiveclcvx(cvx, shortdesc, archivedt)
      select 
         cvx, 
         shortDescription, 
         getdate()
      from dbo.CLCVX
   end

   delete dbo.CLCVX;

   insert into dbo.CLCVX(cvx,shortDescription)
   select 
      [cvxcode],
      left(ltrim(rtrim([shortdesc])),100) 
   from @cvx 
end
   
-- [CLVACCINEPRODUCT] Archive and Insert/Delete
begin

   if exists(select * from dbo.CLVACCINEPRODUCT)
   begin
      insert into dbo.archiveclvaccineproduct(cvx, mvx, cdcname, active, updatedate,archivedt)
      select 
         cvx, 
         mvx, 
         cdcname, 
         active, 
         updatedate, 
         getdate()
      from dbo.CLVACCINEPRODUCT
   end

   delete dbo.CLVACCINEPRODUCT;

   insert into dbo.CLVACCINEPRODUCT(cvx, mvx, cdcname, active, updatedate)
   select distinct
      t.[cvxcode], 
      left(ltrim(rtrim(t.[mvxcode])),3), 
      left(ltrim(rtrim(t.[cdcprodname])),100),
      case t.[prodnamestatus]
         when 'Active' then 'Y'
         when 'Inactive' then 'N'
      else 'N' end,
      t.[lastupdatedate] 
   from @tradename t 
 
end
 
-- [CLVISHANDOUT] Archive And Insert/Delete
begin
   if exists(select * from dbo.CLVISHANDOUT)
   insert into dbo.archiveclvishandout(cvx,handoutid,documentname,editiondate,editionactive,genericcvx,archivedt)
   select 
      cvx,
      handoutid,
      documentname,
      editiondate,
      editionactive,
      genericcvx,
      getdate()
   from dbo.CLVISHANDOUT;

   delete dbo.CLVISHANDOUT;
    
   insert into dbo.CLVISHANDOUT(cvx,handoutid,documentName,editionDate,editionActive,genericCVX)
   select
      [cvxcode],
      row_number() over (order by [cvxcode],[visdocumentname]) [handoutid],
      [visdocumentname],
      [viseditiondate],
    [viseditionstatus],
      [cvxforvaccinegroup]
   from
   (
      select
        cvis.[cvxcode], 
        left(ltrim(rtrim(cvis.[visdocumentname])),100) [visdocumentname], 
      cvis.[viseditiondate],
        case cvis.[viseditionstatus] 
        when 'Current' 
           then 'Y' 
           else 'N' 
        end [viseditionstatus],
        vg.[cvxforvaccinegroup] 
      from @cvx_vis [cvis]
         inner join @vg vg on cvis.[cvxcode] = vg.[cvxcode]
         and vg.vaccinestatus    in( 'Pending', 'Active' )
      where cvis.viseditionstatus = 'Current'
        and vg.cvxforvaccinegroup = cvis.cvxforvaccinegroup
     
      union

      select 
         cvis.[cvxcode], 
         left(ltrim(rtrim(cvis.[visdocumentname])),100) [visdocumentname], 
         cvis.[viseditiondate],
         case cvis.[viseditionstatus] 
         when 'Current' 
            then 'Y' 
            else 'N' 
         end [viseditionstatus],
         0 [cvxforvaccinegroup] 
       from @cvx_vis [cvis] 
       where cvis.viseditionstatus = 'Current'
          and cvis.cvxforvaccinegroup is null
    ) as [q] 
end

-- [CLVALUESETS] Add/Replace VACCINE_IIS
insert into dbo.CLVALUESETS (COMPANY, SECTION, CODE, [DESCRIPTION], VALUESETID, BEGINDATE, ENDDATE, LASTEDIT, LASTUSER, ACTIVE, DISPLAYRANK) 
select 
   '[ALL]', 
   'VACCINE_IIS', 
   cvx, 
   shortDescription, 
   '2.16.840.1.114222.4.11.826', 
   '1900-01-01 00:00:00.000', 
   '1900-01-01 00:00:00.000', 
   GETDATE(), 
   'MEDINFO', 
   'Y', 
   NULL 
from dbo.CLCVX C
   LEFT JOIN dbo.CLVALUESETS CLV ON CLV.COMPANY = '[ALL]'
      AND CLV.SECTION = 'VACCINE_IIS'
      AND CLV.CODE = C.CVX
WHERE CLV.CODE IS NULL;

DELETE dbo.CLVALUESETS  
WHERE COMPANY = '[ALL]'
   AND SECTION = 'VACCINE_IIS'
   AND NOT EXISTS(
                     SELECT * 
                     FROM dbo.CLCVX C 
                     WHERE C.CVX = CLVALUESETS.CODE
                 );

-- [CLVALUESETS].VISMAP
insert into dbo.CLVALUESETS (COMPANY, SECTION, CODE, [DESCRIPTION], VALUESETID, BEGINDATE, ENDDATE, LASTEDIT, LASTUSER, ACTIVE, DISPLAYRANK) 
select distinct
   COMPANY = '[ALL]', 
   SECTION = 'VISMAP', 
   CODE    = c.[cvxcode], 
   min(vga.[vaccinegroupname]) [DESCRIPTION], 
   'CDC_VIS'    VALUESETID, 
   '1900-01-01' BEGINDATE, 
   '1900-01-01' ENDDATE, 
   GETDATE()    LASTEDIT,  
   'MEDINFO'    LASTUSER, 
   'Y'          ACTIVE, 
   null         DISPLAYRANK
from @cvx_vis c join @VG vga on c.[cvxvaccinedesc] = vga.[shortdesc] 
    and c.[viseditionstatus] <> 'Historic' 
    and vga.[vaccinestatus]  in( 'Pending','Active')
left join dbo.CLVALUESETS CLV ON CLV.COMPANY = '[ALL]'
    and CLV.SECTION = 'VISMAP'
    and CLV.VALUESETID = 'CDC_VIS'  
    and CLV.CODE = CAST(C.[cvxcode] AS INT)
WHERE CLV.COMPANY IS NULL  
group by c.[cvxcode]; 
 
DELETE dbo.CLVALUESETS
WHERE COMPANY     = '[ALL]'
   AND SECTION    = 'VISMAP'
   AND VALUESETID = 'CDC_VIS'
   AND NOT EXISTS(
                    SELECT * 
                    FROM @cvx_vis c 
                       INNER Join @VG vga on c.[cvxvaccinedesc] = vga.[shortdesc] 
                          AND c.[viseditionstatus] <> 'Historic' 
                          AND vga.[vaccinestatus]  in( 'Pending','Active' )
                          AND  CLVALUESETS.CODE = CAST(C.[cvxcode] AS INT)
                 );

INSERT INTO dbo.CLVALUESETS (COMPANY, SECTION, CODE, [DESCRIPTION], VALUESETID, BEGINDATE, ENDDATE, LASTEDIT, LASTUSER, ACTIVE, DISPLAYRANK) 
SELECT 
   DISTINCT '[ALL]', 
            'VISMFC', 
            t.[mvxcode], 
            left(ltrim(rtrim(t.[manufacturer])),100), 
            '2.16.840.1.114222.4.11.826', 
            '1900-01-01 00:00:00.000', 
            '1900-01-01 00:00:00.000', 
            GETDATE(), 
            'MEDINFO', 
            CASE WHEN T.[mvxstatus] = 'Active' then 'Y' else 'N' end, 
            NULL
from @tradename t 
   left join dbo.CLVALUESETS CLV on CLV.COMPANY = '[ALL]'
      AND CLV.SECTION = 'VISMFC'
      AND CLV.CODE = t.[mvxcode]  
where CLV.COMPANY IS NULL
   AND T.[mvxcode] <> ''
   AND T.[mvxstatus] = 'ACTIVE';

DELETE dbo.CLVALUESETS 
WHERE COMPANY = '[ALL]'
   AND CLVALUESETS.SECTION = 'VISMFC'
   AND NOT EXISTS(SELECT * 
                  FROM @TRADENAME T 
                  WHERE T.[mvxcode] = CLVALUESETS.CODE 
                     AND T.[mvxstatus] = 'ACTIVE');


if not exists(select * from dbo.CLVALUESETS where SECTION = 'VISMFC' and code='UNK' and company = '[ALL]')
   begin
      INSERT INTO dbo.CLVALUESETS (COMPANY, SECTION, CODE, [DESCRIPTION], VALUESETID, BEGINDATE, ENDDATE, LASTEDIT, LASTUSER, ACTIVE, DISPLAYRANK) 
      select 
         '[ALL]', 
         'VISMFC',
         'UNK',
         'Unknown Product',
         '2.16.840.1.114222.4.11.826',
         '1900-01-01 00:00:00.000',
         '1900-01-01 00:00:00.000', 
         getdate(),
         'MEDINFO',
         'Y',
         null
   end
go

-- log support script ran
INSERT INTO CLSYSLOG (COMPANY,SDATE,EVENTGROUP,EVENTCODE,EVENTDESC,USERCODE)
SELECT
   'MAIN',
   GETDATE(),
   'SS',
   'VACCINE',
   'CVX MVX VACCINE UDPDATE',
   'MEDINFO';
GO
 
ALTER PROCEDURE [dbo].[mi_clVISHandoutSel] @CVX int
AS

  SELECT  h.documentName,
      h.editionDate,
      h.genericCVX
  FROM  CLCVX c
      LEFT OUTER JOIN CLVISHANDOUT h
      ON  c.cvx = h.cvx
  WHERE c.cvx = @CVX
     and h.editionActive = 'Y';
GO
"@

Add-Content -Path $output_file -value $script_footer

Add-Content -Path $output_file -value "`n"
