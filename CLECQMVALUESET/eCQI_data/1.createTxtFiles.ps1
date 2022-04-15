$input_path = "./0.eCQI - CMS"
$output_path = "./1.QDM_separated"

$file_names = Get-ChildItem -Path $input_path | 
              Select-Object -Property @{name="file_name";expression={$_.Name + ".txt"}}


$file_names | ForEach-Object {
  New-Item -Path $output_path -Name $_."file_name" -ItemType file
}

