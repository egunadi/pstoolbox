# /Users/egunadi/Documents/SQL/Modules/HDL/FR-001934_holdReasons/old/modified
# /Users/egunadi/Documents/SQL/Modules/HDL/FR-001514_errorCnt/modified

#https://stackoverflow.com/questions/8749929/how-do-i-concatenate-two-text-files-in-powershell

Get-Content storedProcedures/* | Set-Content concatenatedSPs.sql

<#
cat example*.txt | sc allexamples.txt

The cat is an alias for Get-Content, and sc is an alias for Set-Content.

Note 1: Be careful with the latter method - if you try to output to examples.txt (or similar that matches the pattern), PowerShell will get into an infinite loop! (I just tested this).

Note 2: Outputting to a file with > does not preserve character encoding! This is why using Set-Content (sc) is recommended.

#>