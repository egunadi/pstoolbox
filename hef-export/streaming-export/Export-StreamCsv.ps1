param (
    $query,
    $exportpath
)

$ConnectionString = "Server=localhost;Integrated Security=true;Initial Catalog=medical"
$streamWriter = New-Object System.IO.StreamWriter $exportpath
$sqlConn = New-Object System.Data.SqlClient.SqlConnection $ConnectionString
$sqlCmd = New-Object System.Data.SqlClient.SqlCommand
$sqlCmd.Connection = $sqlConn
$sqlCmd.CommandText = $query
$sqlCmd.CommandTimeout = 0
$sqlConn.Open();
$reader = $sqlCmd.ExecuteReader();

# Initialize the array the hold the values
$array = @()
for ( $i = 0 ; $i -lt $reader.FieldCount; $i++ ) 
    { $array += @($i) }

# Write Header
$streamWriter.Write('"' + $reader.GetName(0) + '"')
for ( $i = 1; $i -lt $reader.FieldCount; $i ++) 
{ $streamWriter.Write($("," + '"' + $reader.GetName($i) + '"')) }

$streamWriter.WriteLine("") # Close the header line

while ($reader.Read())
{
    # get the values;
    $fieldCount = $reader.GetValues($array);

    for ($i = 0; $i -lt $array.Length; $i++)
    {       
        #  if the values have a quotes, escape with quotes
        if ($array[$i].ToString().Contains('"'))
        {
            $array[$i] = $array[$i].Replace('"','""')
        }
        
        # add quotes
        $array[$i] = '"' + $array[$i].ToString().Trim() + '"'
    }

    $newRow = [string]::Join(",", $array);

    $streamWriter.WriteLine($newRow)
}
$reader.Close();
$sqlConn.Close();
$streamWriter.Close();
