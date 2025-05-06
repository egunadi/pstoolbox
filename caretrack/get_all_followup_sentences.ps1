$basePath = "D:\MIINTERFACE\CARETRACK\Processed"
$outputCsv = "D:\MIINTERFACE\CARETRACK\followup_sentences.csv"  

# Collect all the results
$results = Get-ChildItem -Path $basePath -Recurse -Filter *.json | ForEach-Object {
    $jsonContent = Get-Content $_.FullName -Raw | ConvertFrom-Json
    if ($jsonContent.followup_sentences) {
        foreach ($sentenceObj in $jsonContent.followup_sentences) {
            if ($sentenceObj.sentence) {
                [PSCustomObject]@{
                    FilePath   = $_.FullName
                    Sentence   = $sentenceObj.sentence
                    Confidence = $sentenceObj.confidence
                }
            }
        }
    }
}

# Export to CSV
$results | Export-Csv -Path $outputCsv -NoTypeInformation -Encoding UTF8

Write-Host "Done! Extracted data saved to $outputCsv"
