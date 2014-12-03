function New-VirtualMachineFloppyImage {
<#
.SYNOPSIS 
SCCM Static IP Addressing Floppy creation script


.DESCRIPTION
The VMBuildFloppy script is used to generate, copy and mount the virtual floppy image to the target virtual machine.


.NOTES

See module manifest for required software versions and dependencies at:
http://dfch.biz/biz/dfch/PS/Cumulus/VI/biz.dfch.PS.Cumulus.VI.psd1/

Requires 'bfi.exe' for floppy build


#>

param
(

	[Parameter(Mandatory = $false, Position = 0)]
	[ValidateNotNullOrEmpty()]
	[string[]] $vCenterNames
	,
	[Parameter(Mandatory = $false, Position = 1)]
	[ValidateNotNullOrEmpty()]
	[System.Management.Automation.PSCredential] $vCenterCred
	,
	[Parameter(Mandatory = $true, Position = 2)]
	[ValidateNotNullOrEmpty()]
	[string] $VMname
	,
	[Parameter(Mandatory = $true, Position = 3)]
	[ValidateNotNullOrEmpty()]
	[string] $IpAddr
	,
	[Parameter(Mandatory = $true, Position = 4)]
	[ValidateNotNullOrEmpty()]
	[string] $Subnet
	,
	[Parameter(Mandatory = $true, Position = 5)]
	[ValidateNotNullOrEmpty()]
	[string] $Gateway
	,
	[Parameter(Mandatory = $true, Position = 6)]
	[ValidateNotNullOrEmpty()]
	[string] $PrimDNS
	,
	[Parameter(Mandatory = $true, Position = 7)]
	[ValidateNotNullOrEmpty()]
	[string] $SeconDNS
	,
	[Parameter(Mandatory = $true, Position = 8)]
	[ValidateNotNullOrEmpty()]
	[string] $DNSSufix
	,
	[ValidateScript( { Test-Path($_) -PathType Container;} )]
	[Parameter(Mandatory = $false, Position = 9)]
	[ValidateNotNullOrEmpty()]
	[string] $basePath = "$env:ProgramFiles\dfch\cumulus\IPDeployment"
	,
	[Parameter(Mandatory = $false, Position = 10)]
	[ValidateNotNullOrEmpty()]
	[string] $configFile
	,
	[ValidateScript( { Test-Path($_) -PathType Leaf; } )]
	[Parameter(Mandatory = $false, Position = 11)]
	[ValidateNotNullOrEmpty()]
	[string] $BFISoftFile=( Join-Path  $basePath 'SourceSoftware\bfi10\bfi.exe' )
	,
	[Parameter(Mandatory = $false, Position = 12)]
	[ValidateNotNullOrEmpty()]
	[boolean] $disconnectVC = $false
)

	try 
	{

		[string] $fn = $MyInvocation.MyCommand.Name;
		
		#start logging
		$datBegin = [datetime]::Now;
		Log-Debug -fn $fn -msg ("Call");
		
		Log-Debug -fn $fn -msg ('Floppy Content Parameters: IpAddr:{0} Subnet:{1} Gateway:{2} PrimDNS:{3} SeconDNS:{4} DNSSufix:{5}' -f $IpAddr, $Subnet, $Gateway , $PrimDNS, $SeconDNS, $DNSSufix);
		
		$guiD = [guid]::NewGuid().Guid
		
		Log-Debug -fn $fn -msg ("Check if floppy generator exe exists: {0}" -f $BFISoftFile);
		if( ! (Test-Path $BFISoftFile) )
		{
			throw ( "Required software is not available on the given path: {0}" -f $BFISoftFile )
		}

		#If no basePath is passed as parameter, use the current script path
		if( !$basePath )
		{
			#Fix in module not available!!!
			$ScriptDir = Split-Path $MyInvocation.MyCommand.Path;
			$basePath = $ScriptDir;
		}
		$VMDepot = Join-Path -Path $basePath -ChildPath "VM";


		#If no configFile is passed as a parameter, use the current script path
		if( !$configFile )
		{
			$configFile = (Join-Path -Path $VMDepot -ChildPath VMbuildFloppyConf.xml)
		}
		
		Log-Debug -fn $fn -msg ("Load config file '{0}' " -f $configfile);
					
		
		
		#Verify vCenter Connections
		if( $null -ne $vCenterNames)
		{
			if( $vCenterCred) { Set-vCenterConnections -vCenterNames $vCenterNames -vCenterCred $vCenterCred } else { Set-vCenterConnections -vCenterNames $vCenterNames } 
		}
		#set Programm paths
		#################
		#create temp space
		$VMFloppyTMP = (Join-Path -Path $VMDepot -ChildPath $VMName)
		if (Test-Path $VMFloppyTMP)
		{
			Log-Debug -fn $fn -msg ("Remove old temp space '{0}'" -f  $VMFloppyTMP);
			Remove-Item -Recurse -force  $VMFloppyTMP  | Out-Null
		}
		Log-Debug -fn $fn -msg ("Create temp space '{0}'" -f  $VMFloppyTMP);
		New-Item -ItemType directory -Path $VMFloppyTMP | Out-Null
		$IPOutFile = Join-Path -Path $VMFloppyTMP -ChildPath "ipconf.txt"
		$flpName = ("{0}_flp.img" -f $VMName)
		$flpImage = Join-Path -Path $VMDepot -ChildPath $flpName

		#create floppy
		#################
		#write ipconf file
		Log-Debug -fn $fn -msg ("Writing outputfile {0} - {1} - {2}" -f $IPOutFile, $flpName, $flpImage)
		write $IpAddr | out-file -Encoding ASCII $IPOutFile
		write $Subnet | out-file -Encoding ASCII -Append $IPOutFile
		write $Gateway | out-file -Encoding ASCII -Append $IPOutFile
		write $primDNS | out-file -Encoding ASCII -Append $IPOutFile
		write $seconDNS | out-file -Encoding ASCII -Append $IPOutFile
		write $DNSSufix | out-file -Encoding ASCII -Append $IPOutFile
		#create floppy
		& $BFISoftFile ("-f="+$flpImage) $VMFloppyTMP

		#connect to vCenter
					
		$vm = Get-VM -Name $VMName
		#Validate Result
		if( ($null -ne $VM) -and  ( 'VirtualMachineImpl' -eq $VM.GetType().Name) )
		{
			Log-Debug -fn $fn -msg ( 'VM Found: {0}' -f $VMname )
		} 
		else 
		{
			$e = New-CustomErrorRecord -m ( 'VM validation failed: {0}' -f $VMName )
			throw($gotoError);
		}
				
		#Copy flp to Datastore
		$temp=$vm.ExtensionData.config.files.VMPathName
		if ($temp -match "\[([^\]]+)\].([^\/]+)/(.*)") 
		{
			$datastore = $VM.Host | Get-Datastore -Name $Matches[1]
			$VMfolder=$Matches[2]
			Log-Debug -fn $fn -msg ("Using folder '{0}'" -f $VMfolder);
		}
		$msg = New-PSDrive -location $datastore -name ds -PSProvider VimDatastore -Root "\"
		Log-Debug -fn $fn -msg ("{0} - create Datastore drive" -f $VMname);
		Set-Location ds:\$VMfolder 
		Log-Debug -fn $fn -msg ("{0} - Copy flp file to datastore: $datastore and Folder: $VMfolder" -f $VMname)
		
		$msg = Copy-DatastoreItem -Item $flpImage -Destination ds:\$VMfolder
		Log-Debug -fn $fn -msg ("{0} copy flp to DS $msg" -f $VMname);

		# mount ISO
		$flpPath = "["+$datastore+"] "+$VMfolder+"/"+$flpname
		
		Log-Debug -fn $fn -msg ("{0} Mounting flp path {1}" -f $VMname, $flpPath );
		
		if( $vm.PowerState -eq "PoweredOn")
		{
			Log-Debug -fn $fn -msg ("{0} VM is powered on - set floppy connected" -f $VMname );
			$msg=$vm | Get-FloppyDrive | Set-FloppyDrive -FloppyImagePath $flpPath -Connected:$true -Confirm:$false
			
		} 
		else 
		{
			
			Log-Debug -fn $fn -msg ("{0} VM is powered off - set floppy StartConnected" -f $VMname );
			$msg=$vm | Get-FloppyDrive | Set-FloppyDrive -FloppyImagePath $flpPath -StartConnected:$true -Confirm:$false
		}

	}
	catch 
	{

		Log-Error -fn $fn -msg ("Program failed")
		#get error
		[string] $ErrorText = "catch [$($_.FullyQualifiedErrorId)]";
		$ErrorText += (($_ | fl * -Force) | Out-String);
		$ErrorText += (($_.Exception | fl * -Force) | Out-String);
		$ErrorText += (Get-PSCallStack | Out-String);
		Log-Error -fn $fn -msg $ErrorText;

	}
	finally 
	{

		#cleanup and exit
		#################
		# delete temp area
		Log-Debug -fn $fn -msg ("Cleanup");
		Set-Location $basePath
		
		if( Test-Path ds )
		{
			$msg=Remove-PSDrive -Name ds -PSProvider VimDatastore
		}
		
		if( test-path $VMFloppyTMP )
		{
			Log-Debug -fn $fn -msg ( "Remove Floppy Temp Location: {0}" -f $VMFloppyTMP );
			Remove-Item -Recurse -force $VMFloppyTMP  | Out-Null
		}
		
		if( test-path $flpImage )
		{
			Log-Debug -fn $fn -msg ( "Remove Floppy Image Location: {0}" -f $flpImage );
			Remove-Item $flpImage -force | Out-Null
		}
		
		if( $disconnectVC )
		{
			Log-Debug -fn $fn -msg ( "Disconnect vCenter Server: {0}" -f $vCenterNames );
			Disconnect-VIServer $vCenterName -Confirm:$false | Out-Null
		}
		
		$datEnd = [datetime]::Now;
		Log-Debug -fn $fn -msg ("End time '{0}' " -f $datEnd);
	} # finally

} # function

if($MyInvocation.ScriptName) { Export-ModuleMember -Function New-VirtualMachineFloppyImage; } 


# SIG # Begin signature block
# MIIW3AYJKoZIhvcNAQcCoIIWzTCCFskCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUiUoR98dRwXLFJ5KAZY7jFLQe
# NEigghGYMIIEFDCCAvygAwIBAgILBAAAAAABL07hUtcwDQYJKoZIhvcNAQEFBQAw
# VzELMAkGA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2ExEDAOBgNV
# BAsTB1Jvb3QgQ0ExGzAZBgNVBAMTEkdsb2JhbFNpZ24gUm9vdCBDQTAeFw0xMTA0
# MTMxMDAwMDBaFw0yODAxMjgxMjAwMDBaMFIxCzAJBgNVBAYTAkJFMRkwFwYDVQQK
# ExBHbG9iYWxTaWduIG52LXNhMSgwJgYDVQQDEx9HbG9iYWxTaWduIFRpbWVzdGFt
# cGluZyBDQSAtIEcyMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAlO9l
# +LVXn6BTDTQG6wkft0cYasvwW+T/J6U00feJGr+esc0SQW5m1IGghYtkWkYvmaCN
# d7HivFzdItdqZ9C76Mp03otPDbBS5ZBb60cO8eefnAuQZT4XljBFcm05oRc2yrmg
# jBtPCBn2gTGtYRakYua0QJ7D/PuV9vu1LpWBmODvxevYAll4d/eq41JrUJEpxfz3
# zZNl0mBhIvIG+zLdFlH6Dv2KMPAXCae78wSuq5DnbN96qfTvxGInX2+ZbTh0qhGL
# 2t/HFEzphbLswn1KJo/nVrqm4M+SU4B09APsaLJgvIQgAIMboe60dAXBKY5i0Eex
# +vBTzBj5Ljv5cH60JQIDAQABo4HlMIHiMA4GA1UdDwEB/wQEAwIBBjASBgNVHRMB
# Af8ECDAGAQH/AgEAMB0GA1UdDgQWBBRG2D7/3OO+/4Pm9IWbsN1q1hSpwTBHBgNV
# HSAEQDA+MDwGBFUdIAAwNDAyBggrBgEFBQcCARYmaHR0cHM6Ly93d3cuZ2xvYmFs
# c2lnbi5jb20vcmVwb3NpdG9yeS8wMwYDVR0fBCwwKjAooCagJIYiaHR0cDovL2Ny
# bC5nbG9iYWxzaWduLm5ldC9yb290LmNybDAfBgNVHSMEGDAWgBRge2YaRQ2XyolQ
# L30EzTSo//z9SzANBgkqhkiG9w0BAQUFAAOCAQEATl5WkB5GtNlJMfO7FzkoG8IW
# 3f1B3AkFBJtvsqKa1pkuQJkAVbXqP6UgdtOGNNQXzFU6x4Lu76i6vNgGnxVQ380W
# e1I6AtcZGv2v8Hhc4EvFGN86JB7arLipWAQCBzDbsBJe/jG+8ARI9PBw+DpeVoPP
# PfsNvPTF7ZedudTbpSeE4zibi6c1hkQgpDttpGoLoYP9KOva7yj2zIhd+wo7AKvg
# IeviLzVsD440RZfroveZMzV+y5qKu0VN5z+fwtmK+mWybsd+Zf/okuEsMaL3sCc2
# SI8mbzvuTXYfecPlf5Y1vC0OzAGwjn//UYCAp5LUs0RGZIyHTxZjBzFLY7Df8zCC
# BCgwggMQoAMCAQICCwQAAAAAAS9O4TVcMA0GCSqGSIb3DQEBBQUAMFcxCzAJBgNV
# BAYTAkJFMRkwFwYDVQQKExBHbG9iYWxTaWduIG52LXNhMRAwDgYDVQQLEwdSb290
# IENBMRswGQYDVQQDExJHbG9iYWxTaWduIFJvb3QgQ0EwHhcNMTEwNDEzMTAwMDAw
# WhcNMTkwNDEzMTAwMDAwWjBRMQswCQYDVQQGEwJCRTEZMBcGA1UEChMQR2xvYmFs
# U2lnbiBudi1zYTEnMCUGA1UEAxMeR2xvYmFsU2lnbiBDb2RlU2lnbmluZyBDQSAt
# IEcyMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAsk8U5xC+1yZyqzaX
# 71O/QoReWNGKKPxDRm9+KERQC3VdANc8CkSeIGqk90VKN2Cjbj8S+m36tkbDaqO4
# DCcoAlco0VD3YTlVuMPhJYZSPL8FHdezmviaJDFJ1aKp4tORqz48c+/2KfHINdAw
# e39OkqUGj4fizvXBY2asGGkqwV67Wuhulf87gGKdmcfHL2bV/WIaglVaxvpAd47J
# MDwb8PI1uGxZnP3p1sq0QB73BMrRZ6l046UIVNmDNTuOjCMMdbbehkqeGj4KUEk4
# nNKokL+Y+siMKycRfir7zt6prjiTIvqm7PtcYXbDRNbMDH4vbQaAonRAu7cf9DvX
# c1Qf8wIDAQABo4H6MIH3MA4GA1UdDwEB/wQEAwIBBjASBgNVHRMBAf8ECDAGAQH/
# AgEAMB0GA1UdDgQWBBQIbti2nIq/7T7Xw3RdzIAfqC9QejBHBgNVHSAEQDA+MDwG
# BFUdIAAwNDAyBggrBgEFBQcCARYmaHR0cHM6Ly93d3cuZ2xvYmFsc2lnbi5jb20v
# cmVwb3NpdG9yeS8wMwYDVR0fBCwwKjAooCagJIYiaHR0cDovL2NybC5nbG9iYWxz
# aWduLm5ldC9yb290LmNybDATBgNVHSUEDDAKBggrBgEFBQcDAzAfBgNVHSMEGDAW
# gBRge2YaRQ2XyolQL30EzTSo//z9SzANBgkqhkiG9w0BAQUFAAOCAQEAIlzF3T30
# C3DY4/XnxY4JAbuxljZcWgetx6hESVEleq4NpBk7kpzPuUImuztsl+fHzhFtaJHa
# jW3xU01UOIxh88iCdmm+gTILMcNsyZ4gClgv8Ej+fkgHqtdDWJRzVAQxqXgNO4yw
# cME9fte9LyrD4vWPDJDca6XIvmheXW34eNK+SZUeFXgIkfs0yL6Erbzgxt0Y2/PK
# 8HvCFDwYuAO6lT4hHj9gaXp/agOejUr58CgsMIRe7CZyQrFty2TDEozWhEtnQXyx
# Axd4CeOtqLaWLaR+gANPiPfBa1pGFc0sGYvYcJzlLUmIYHKopBlScENe2tZGA7Bo
# DiTvSvYLJSTvJDCCBJ8wggOHoAMCAQICEhEhQFwfDtJYiCvlTYaGuhHqRTANBgkq
# hkiG9w0BAQUFADBSMQswCQYDVQQGEwJCRTEZMBcGA1UEChMQR2xvYmFsU2lnbiBu
# di1zYTEoMCYGA1UEAxMfR2xvYmFsU2lnbiBUaW1lc3RhbXBpbmcgQ0EgLSBHMjAe
# Fw0xMzA4MjMwMDAwMDBaFw0yNDA5MjMwMDAwMDBaMGAxCzAJBgNVBAYTAlNHMR8w
# HQYDVQQKExZHTU8gR2xvYmFsU2lnbiBQdGUgTHRkMTAwLgYDVQQDEydHbG9iYWxT
# aWduIFRTQSBmb3IgTVMgQXV0aGVudGljb2RlIC0gRzEwggEiMA0GCSqGSIb3DQEB
# AQUAA4IBDwAwggEKAoIBAQCwF66i07YEMFYeWA+x7VWk1lTL2PZzOuxdXqsl/Tal
# +oTDYUDFRrVZUjtCoi5fE2IQqVvmc9aSJbF9I+MGs4c6DkPw1wCJU6IRMVIobl1A
# cjzyCXenSZKX1GyQoHan/bjcs53yB2AsT1iYAGvTFVTg+t3/gCxfGKaY/9Sr7KFF
# WbIub2Jd4NkZrItXnKgmK9kXpRDSRwgacCwzi39ogCq1oV1r3Y0CAikDqnw3u7sp
# Tj1Tk7Om+o/SWJMVTLktq4CjoyX7r/cIZLB6RA9cENdfYTeqTmvT0lMlnYJz+iz5
# crCpGTkqUPqp0Dw6yuhb7/VfUfT5CtmXNd5qheYjBEKvAgMBAAGjggFfMIIBWzAO
# BgNVHQ8BAf8EBAMCB4AwTAYDVR0gBEUwQzBBBgkrBgEEAaAyAR4wNDAyBggrBgEF
# BQcCARYmaHR0cHM6Ly93d3cuZ2xvYmFsc2lnbi5jb20vcmVwb3NpdG9yeS8wCQYD
# VR0TBAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDBCBgNVHR8EOzA5MDegNaAz
# hjFodHRwOi8vY3JsLmdsb2JhbHNpZ24uY29tL2dzL2dzdGltZXN0YW1waW5nZzIu
# Y3JsMFQGCCsGAQUFBwEBBEgwRjBEBggrBgEFBQcwAoY4aHR0cDovL3NlY3VyZS5n
# bG9iYWxzaWduLmNvbS9jYWNlcnQvZ3N0aW1lc3RhbXBpbmdnMi5jcnQwHQYDVR0O
# BBYEFNSihEo4Whh/uk8wUL2d1XqH1gn3MB8GA1UdIwQYMBaAFEbYPv/c477/g+b0
# hZuw3WrWFKnBMA0GCSqGSIb3DQEBBQUAA4IBAQACMRQuWFdkQYXorxJ1PIgcw17s
# LOmhPPW6qlMdudEpY9xDZ4bUOdrexsn/vkWF9KTXwVHqGO5AWF7me8yiQSkTOMjq
# IRaczpCmLvumytmU30Ad+QIYK772XU+f/5pI28UFCcqAzqD53EvDI+YDj7S0r1tx
# KWGRGBprevL9DdHNfV6Y67pwXuX06kPeNT3FFIGK2z4QXrty+qGgk6sDHMFlPJET
# iwRdK8S5FhvMVcUM6KvnQ8mygyilUxNHqzlkuRzqNDCxdgCVIfHUPaj9oAAy126Y
# PKacOwuDvsu4uyomjFm4ua6vJqziNKLcIQ2BCzgT90Wj49vErKFtG7flYVzXMIIE
# rTCCA5WgAwIBAgISESFgd9/aXcgt4FtCBtsrp6UyMA0GCSqGSIb3DQEBBQUAMFEx
# CzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9iYWxTaWduIG52LXNhMScwJQYDVQQD
# Ex5HbG9iYWxTaWduIENvZGVTaWduaW5nIENBIC0gRzIwHhcNMTIwNjA4MDcyNDEx
# WhcNMTUwNzEyMTAzNDA0WjB6MQswCQYDVQQGEwJERTEbMBkGA1UECBMSU2NobGVz
# d2lnLUhvbHN0ZWluMRAwDgYDVQQHEwdJdHplaG9lMR0wGwYDVQQKDBRkLWZlbnMg
# R21iSCAmIENvLiBLRzEdMBsGA1UEAwwUZC1mZW5zIEdtYkggJiBDby4gS0cwggEi
# MA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDTG4okWyOURuYYwTbGGokj+lvB
# go0dwNYJe7HZ9wrDUUB+MsPTTZL82O2INMHpQ8/QEMs87aalzHz2wtYN1dUIBUae
# dV7TZVme4ycjCfi5rlL+p44/vhNVnd1IbF/pxu7yOwkAwn/iR+FWbfAyFoCThJYk
# 9agPV0CzzFFBLcEtErPJIvrHq94tbRJTqH9sypQfrEToe5kBWkDYfid7U0rUkH/m
# bff/Tv87fd0mJkCfOL6H7/qCiYF20R23Kyw7D2f2hy9zTcdgzKVSPw41WTsQtB3i
# 05qwEZ3QCgunKfDSCtldL7HTdW+cfXQ2IHItN6zHpUAYxWwoyWLOcWcS69InAgMB
# AAGjggFUMIIBUDAOBgNVHQ8BAf8EBAMCB4AwTAYDVR0gBEUwQzBBBgkrBgEEAaAy
# ATIwNDAyBggrBgEFBQcCARYmaHR0cHM6Ly93d3cuZ2xvYmFsc2lnbi5jb20vcmVw
# b3NpdG9yeS8wCQYDVR0TBAIwADATBgNVHSUEDDAKBggrBgEFBQcDAzA+BgNVHR8E
# NzA1MDOgMaAvhi1odHRwOi8vY3JsLmdsb2JhbHNpZ24uY29tL2dzL2dzY29kZXNp
# Z25nMi5jcmwwUAYIKwYBBQUHAQEERDBCMEAGCCsGAQUFBzAChjRodHRwOi8vc2Vj
# dXJlLmdsb2JhbHNpZ24uY29tL2NhY2VydC9nc2NvZGVzaWduZzIuY3J0MB0GA1Ud
# DgQWBBTwJ4K6WNfB5ea1nIQDH5+tzfFAujAfBgNVHSMEGDAWgBQIbti2nIq/7T7X
# w3RdzIAfqC9QejANBgkqhkiG9w0BAQUFAAOCAQEAB3ZotjKh87o7xxzmXjgiYxHl
# +L9tmF9nuj/SSXfDEXmnhGzkl1fHREpyXSVgBHZAXqPKnlmAMAWj0+Tm5yATKvV6
# 82HlCQi+nZjG3tIhuTUbLdu35bss50U44zNDqr+4wEPwzuFMUnYF2hFbYzxZMEAX
# Vlnaj+CqtMF6P/SZNxFvaAgnEY1QvIXI2pYVz3RhD4VdDPmMFv0P9iQ+npC1pmNL
# mCaG7zpffUFvZDuX6xUlzvOi0nrTo9M5F2w7LbWSzZXedam6DMG0nR1Xcx0qy9wY
# nq4NsytwPbUy+apmZVSalSvldiNDAfmdKP0SCjyVwk92xgNxYFwITJuNQIto4zGC
# BK4wggSqAgEBMGcwUTELMAkGA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24g
# bnYtc2ExJzAlBgNVBAMTHkdsb2JhbFNpZ24gQ29kZVNpZ25pbmcgQ0EgLSBHMgIS
# ESFgd9/aXcgt4FtCBtsrp6UyMAkGBSsOAwIaBQCgeDAYBgorBgEEAYI3AgEMMQow
# CKACgAChAoAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcC
# AQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBRS8xhPs5ECWvoCRDr2
# UoWUs+EnbTANBgkqhkiG9w0BAQEFAASCAQAYSLAfRODfDFaaNb0UWhiW5YgqxRtX
# 0b7c8ta1QfcrUYATcTCejZPSJQa7+VpyYEJXXNi/tT++bTLTyDCLIfCny/4S6kpq
# YnZ1Sh0ezUFD8o52Adh5QqxEK5okmZS6weZU9CCwPjR1St+c/N4czark8uOIt9BT
# xhmthyTWwbBdckyAAzcyjQpKtsM74+OkWL8zmU7B/yZb9A0xEfzV08Bon0DrBhfy
# cCDSeKDMA6x8lYRo+yDtlck9tKmRfhorxBHMyesPD+bIrbcotdnS1ZGkLtJiy2Vs
# fuaJOIwxTbkpziu7KImkz73if5K9TCTAF1sDU1czSeR02lONTVhhYwWNoYICojCC
# Ap4GCSqGSIb3DQEJBjGCAo8wggKLAgEBMGgwUjELMAkGA1UEBhMCQkUxGTAXBgNV
# BAoTEEdsb2JhbFNpZ24gbnYtc2ExKDAmBgNVBAMTH0dsb2JhbFNpZ24gVGltZXN0
# YW1waW5nIENBIC0gRzICEhEhQFwfDtJYiCvlTYaGuhHqRTAJBgUrDgMCGgUAoIH9
# MBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTE0MTIw
# MzE1Mjg0MVowIwYJKoZIhvcNAQkEMRYEFGkQj052IMv8T935+BFXLB6hKThhMIGd
# BgsqhkiG9w0BCRACDDGBjTCBijCBhzCBhAQUjOafUBLh0aj7OV4uMeK0K947NDsw
# bDBWpFQwUjELMAkGA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2Ex
# KDAmBgNVBAMTH0dsb2JhbFNpZ24gVGltZXN0YW1waW5nIENBIC0gRzICEhEhQFwf
# DtJYiCvlTYaGuhHqRTANBgkqhkiG9w0BAQEFAASCAQCTNBo8gsRxA0cy1j5ylPNu
# jDIIgy4DWBu8DCiXBwYiyFp4h2FOelhMSEpfCII9Vclpg7ef+TspdNmYMdbzoXeF
# a2WAm6MGa7M3s4SSYcAG0WnKKM+ravMFqcxDOxPowXBeYYMGuEa0jjjCD8GMi7it
# KSJOftLhT0IcgT2/ogp5nBECY607x6QCTRr7J9BwZfIdQkXfvlAcTujgHth93kCf
# 2RHr1lmetGJD378bpycIjPES+TSD6W1owTVybGR9h/hl+oZXsg1ukcSCas7a4WNu
# 4tlvinuORGMtzrlENZ80Nr/GXphEX/IrDi0mnMEJ3MDIb4K0Qss/ggLdzxv7N6EX
# SIG # End signature block