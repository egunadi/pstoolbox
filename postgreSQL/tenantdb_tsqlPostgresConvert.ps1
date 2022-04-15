# /Users/egunadi/Documents/AWS/Projects/tenant/functions

$filePath = '/Users/egunadi/Documents/SQL/DBA/AWS/functions/regex.txt'


(Get-Content $filePath -raw)  | Foreach-Object {
    $_ -replace '\[|\]', ''                 `
        -replace '@', ''                    `
        -replace 'exec dbo', 'select wss'   `
        -replace '=', ':='                  `
        -replace '(select.*)', ('$1 (')     `
        -replace '\Z', ');'
} | Set-Content $filePath