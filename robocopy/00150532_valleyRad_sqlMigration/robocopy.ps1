# https://blog.netnerds.net/2019/09/using-robocopy-to-move-sql-server-files/
robocopy C:\oldmount\Data C:\Mount\Data /MIR /COPYALL /DCOPY:DAT /Z /J /SL /MT:"$([int]$env:NUMBER_OF_PROCESSORS+1)" /R:1 /W:10 /LOG+:C:\temp\robocopy-log.txt /TEE /XD "Recycler" "Recycled" '$Recycle.bin' "System Volume Information" /XF "pagefile.sys" "swapfile.sys" "hiberfil.sys"

robocopy \\10.200.199.57\tmp F:\tmp /COPYALL /Z /J /R:1 /W:10 /LOG+:C:\temp\robocopy-log.txt /TEE

robocopy \\10.200.199.57\tmp E:\tmp /COPYALL /Z /J /MT:"$([int]$env:NUMBER_OF_PROCESSORS+1)" /R:1 /W:10 /LOG+:C:\temp\robocopy-log.txt /TEE
