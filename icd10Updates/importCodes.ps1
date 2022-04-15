$sqlcred = Get-Credential sa
Connect-DbaInstance -SqlInstance localhost -SqlCredential $sqlcred

Get-ChildItem -Path "/Users/egunadi/Documents/Modules/Billing/icd10Updates/2020/v7.6.3.0 and Newer/2020_CLICD9_ICD10_ONLY.csv" | Import-DbaCsv -SqlInstance localhost -SqlCredential $sqlcred -Database Sandbox1 -Table CLICD9_2020 -Quote "'" -Escape "'"

Get-ChildItem -Path "/Users/egunadi/Documents/Modules/Billing/icd10Updates/2021/v7.6.3.0 and Newer/2021_CLICD9_ICD10_ONLY.csv" | Import-DbaCsv -SqlInstance localhost -SqlCredential $sqlcred -Database Sandbox1 -Table CLICD9_2021 -Quote "'" -Escape "'"
