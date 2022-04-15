$filePath = "/Users/egunadi/Documents/tmp/tmp.txt"

(Get-Content $filePath) | Foreach-Object {
  $_  -replace "^", "('" `
      -replace "$", "'),"
} | Set-Content $filePath