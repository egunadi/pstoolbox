# /Users/egunadi/GitHub/mi-pam/Tests-PAM/tests

if (Test-Path install.sql) {
    del install.sql
}

$tests=ls | where {$PSItem.Name -like "test*.sql"} | select -Property Name

foreach($test in $tests){ cat ./$($test.Name) >> install.sql }

ECHO Done