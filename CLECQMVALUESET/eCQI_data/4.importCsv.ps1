$sqlcred = Get-Credential sa
Connect-DbaInstance -SqlInstance localhost -SqlCredential $sqlcred

Get-ChildItem -Path "./4.QDM_excel.csv" | Import-DbaCsv -SqlInstance localhost -SqlCredential $sqlcred -Database 2021_codes -Table qdm_ecqi_html_raw -Delimiter "|"

# If no headers, be sure to use the "-NoHeaderRow" paramete