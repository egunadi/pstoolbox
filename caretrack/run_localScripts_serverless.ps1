
# confirm s3 access
aws s3 ls s3://320574597545-sparkjsl-store

# check caller identity
aws sts get-caller-identity

# install all requirements
cd "c:\Users\egunadi\Git\mi-caretrack\caretrack-core.cfn\lambda_src\processor_function\"
pip install -r C:\Users\egunadi\Git\mi-caretrack\caretrack-core.cfn\lambda_src\processor_function\requirements.txt


<#
anaconda installed in
C:\Users\egunadi\AppData\Local\anaconda3

powershell profiles located in
C:\Users\egunadi\Documents\PowerShell
C:\Users\egunadi\Documents\WindowsPowerShell
#>