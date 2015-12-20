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

	[Parameter(Mandatory = $false)]
	[ValidateNotNullOrEmpty()]
	[string[]] $vCenterNames
	,
	[Parameter(Mandatory = $false)]
	[ValidateNotNullOrEmpty()]
	[PSCredential] $ViCredential
	,
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string] $VMname
	,
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string] $IpAddr
	,
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string] $Subnet
	,
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string] $Gateway
	,
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string] $PrimDNS
	,
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string] $SeconDNS
	,
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string] $DNSSufix
	,
	[ValidateScript( { Test-Path($_) -PathType Container;} )]
	[Parameter(Mandatory = $false)]
	[ValidateNotNullOrEmpty()]
	[string] $basePath = "$env:ProgramFiles\dfch\cumulus\IPDeployment"
	,
	[Parameter(Mandatory = $false)]
	[ValidateNotNullOrEmpty()]
	[string] $configFile
	,
	# DFCHECK TODO remove hard coded path
	[ValidateScript( { Test-Path($_) -PathType Leaf; } )]
	[Parameter(Mandatory = $false)]
	[ValidateNotNullOrEmpty()]
	[string] $BFISoftFile=( Join-Path  $basePath 'SourceSoftware\bfi10\bfi.exe' )
	,
	[Parameter(Mandatory = $false)]
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
			if( $ViCredential) { Set-vCenterConnections -vCenterNames $vCenterNames -vCenterCred $ViCredential } else { Set-vCenterConnections -vCenterNames $vCenterNames } 
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


# 
# Copyright 2014-2015 Ronald Rink, d-fens GmbH
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
# http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# 

# SIG # Begin signature block
# MIIXDwYJKoZIhvcNAQcCoIIXADCCFvwCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU8ZM1pfR5k7MZWJsO5wSgcFP3
# 8AqgghHCMIIEFDCCAvygAwIBAgILBAAAAAABL07hUtcwDQYJKoZIhvcNAQEFBQAw
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
# BCkwggMRoAMCAQICCwQAAAAAATGJxjfoMA0GCSqGSIb3DQEBCwUAMEwxIDAeBgNV
# BAsTF0dsb2JhbFNpZ24gUm9vdCBDQSAtIFIzMRMwEQYDVQQKEwpHbG9iYWxTaWdu
# MRMwEQYDVQQDEwpHbG9iYWxTaWduMB4XDTExMDgwMjEwMDAwMFoXDTE5MDgwMjEw
# MDAwMFowWjELMAkGA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2Ex
# MDAuBgNVBAMTJ0dsb2JhbFNpZ24gQ29kZVNpZ25pbmcgQ0EgLSBTSEEyNTYgLSBH
# MjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAKPv0Z8p6djTgnY8YqDS
# SdYWHvHP8NC6SEMDLacd8gE0SaQQ6WIT9BP0FoO11VdCSIYrlViH6igEdMtyEQ9h
# JuH6HGEVxyibTQuCDyYrkDqW7aTQaymc9WGI5qRXb+70cNCNF97mZnZfdB5eDFM4
# XZD03zAtGxPReZhUGks4BPQHxCMD05LL94BdqpxWBkQtQUxItC3sNZKaxpXX9c6Q
# MeJ2s2G48XVXQqw7zivIkEnotybPuwyJy9DDo2qhydXjnFMrVyb+Vpp2/WFGomDs
# KUZH8s3ggmLGBFrn7U5AXEgGfZ1f53TJnoRlDVve3NMkHLQUEeurv8QfpLqZ0BdY
# Nc0CAwEAAaOB/TCB+jAOBgNVHQ8BAf8EBAMCAQYwEgYDVR0TAQH/BAgwBgEB/wIB
# ADAdBgNVHQ4EFgQUGUq4WuRNMaUU5V7sL6Mc+oCMMmswRwYDVR0gBEAwPjA8BgRV
# HSAAMDQwMgYIKwYBBQUHAgEWJmh0dHBzOi8vd3d3Lmdsb2JhbHNpZ24uY29tL3Jl
# cG9zaXRvcnkvMDYGA1UdHwQvMC0wK6ApoCeGJWh0dHA6Ly9jcmwuZ2xvYmFsc2ln
# bi5uZXQvcm9vdC1yMy5jcmwwEwYDVR0lBAwwCgYIKwYBBQUHAwMwHwYDVR0jBBgw
# FoAUj/BLf6guRSSuTVD6Y5qL3uLdG7wwDQYJKoZIhvcNAQELBQADggEBAHmwaTTi
# BYf2/tRgLC+GeTQD4LEHkwyEXPnk3GzPbrXsCly6C9BoMS4/ZL0Pgmtmd4F/ximl
# F9jwiU2DJBH2bv6d4UgKKKDieySApOzCmgDXsG1szYjVFXjPE/mIpXNNwTYr3MvO
# 23580ovvL72zT006rbtibiiTxAzL2ebK4BEClAOwvT+UKFaQHlPCJ9XJPM0aYx6C
# WRW2QMqngarDVa8z0bV16AnqRwhIIvtdG/Mseml+xddaXlYzPK1X6JMlQsPSXnE7
# ShxU7alVrCgFx8RsXdw8k/ZpPIJRzhoVPV4Bc/9Aouq0rtOO+u5dbEfHQfXUVlfy
# GDcy1tTMS/Zx4HYwggSfMIIDh6ADAgECAhIRIQaggdM/2HrlgkzBa1IJTgMwDQYJ
# KoZIhvcNAQEFBQAwUjELMAkGA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24g
# bnYtc2ExKDAmBgNVBAMTH0dsb2JhbFNpZ24gVGltZXN0YW1waW5nIENBIC0gRzIw
# HhcNMTUwMjAzMDAwMDAwWhcNMjYwMzAzMDAwMDAwWjBgMQswCQYDVQQGEwJTRzEf
# MB0GA1UEChMWR01PIEdsb2JhbFNpZ24gUHRlIEx0ZDEwMC4GA1UEAxMnR2xvYmFs
# U2lnbiBUU0EgZm9yIE1TIEF1dGhlbnRpY29kZSAtIEcyMIIBIjANBgkqhkiG9w0B
# AQEFAAOCAQ8AMIIBCgKCAQEAsBeuotO2BDBWHlgPse1VpNZUy9j2czrsXV6rJf02
# pfqEw2FAxUa1WVI7QqIuXxNiEKlb5nPWkiWxfSPjBrOHOg5D8NcAiVOiETFSKG5d
# QHI88gl3p0mSl9RskKB2p/243LOd8gdgLE9YmABr0xVU4Prd/4AsXximmP/Uq+yh
# RVmyLm9iXeDZGayLV5yoJivZF6UQ0kcIGnAsM4t/aIAqtaFda92NAgIpA6p8N7u7
# KU49U5OzpvqP0liTFUy5LauAo6Ml+6/3CGSwekQPXBDXX2E3qk5r09JTJZ2Cc/os
# +XKwqRk5KlD6qdA8OsroW+/1X1H0+QrZlzXeaoXmIwRCrwIDAQABo4IBXzCCAVsw
# DgYDVR0PAQH/BAQDAgeAMEwGA1UdIARFMEMwQQYJKwYBBAGgMgEeMDQwMgYIKwYB
# BQUHAgEWJmh0dHBzOi8vd3d3Lmdsb2JhbHNpZ24uY29tL3JlcG9zaXRvcnkvMAkG
# A1UdEwQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwQgYDVR0fBDswOTA3oDWg
# M4YxaHR0cDovL2NybC5nbG9iYWxzaWduLmNvbS9ncy9nc3RpbWVzdGFtcGluZ2cy
# LmNybDBUBggrBgEFBQcBAQRIMEYwRAYIKwYBBQUHMAKGOGh0dHA6Ly9zZWN1cmUu
# Z2xvYmFsc2lnbi5jb20vY2FjZXJ0L2dzdGltZXN0YW1waW5nZzIuY3J0MB0GA1Ud
# DgQWBBTUooRKOFoYf7pPMFC9ndV6h9YJ9zAfBgNVHSMEGDAWgBRG2D7/3OO+/4Pm
# 9IWbsN1q1hSpwTANBgkqhkiG9w0BAQUFAAOCAQEAgDLcB40coJydPCroPSGLWaFN
# fsxEzgO+fqq8xOZ7c7tL8YjakE51Nyg4Y7nXKw9UqVbOdzmXMHPNm9nZBUUcjaS4
# A11P2RwumODpiObs1wV+Vip79xZbo62PlyUShBuyXGNKCtLvEFRHgoQ1aSicDOQf
# FBYk+nXcdHJuTsrjakOvz302SNG96QaRLC+myHH9z73YnSGY/K/b3iKMr6fzd++d
# 3KNwS0Qa8HiFHvKljDm13IgcN+2tFPUHCya9vm0CXrG4sFhshToN9v9aJwzF3lPn
# VDxWTMlOTDD28lz7GozCgr6tWZH2G01Ve89bAdz9etNvI1wyR5sB88FRFEaKmzCC
# BNYwggO+oAMCAQICEhEhDRayW4wRltP+V8mGEea62TANBgkqhkiG9w0BAQsFADBa
# MQswCQYDVQQGEwJCRTEZMBcGA1UEChMQR2xvYmFsU2lnbiBudi1zYTEwMC4GA1UE
# AxMnR2xvYmFsU2lnbiBDb2RlU2lnbmluZyBDQSAtIFNIQTI1NiAtIEcyMB4XDTE1
# MDUwNDE2NDMyMVoXDTE4MDUwNDE2NDMyMVowVTELMAkGA1UEBhMCQ0gxDDAKBgNV
# BAgTA1p1ZzEMMAoGA1UEBxMDWnVnMRQwEgYDVQQKEwtkLWZlbnMgR21iSDEUMBIG
# A1UEAxMLZC1mZW5zIEdtYkgwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQDNPSzSNPylU9jFM78Q/GjzB7N+VNqikf/use7p8mpnBZ4cf5b4qV3rqQd62rJH
# RlAsxgouCSNQrl8xxfg6/t/I02kPvrzsR4xnDgMiVCqVRAeQsWebafWdTvWmONBS
# lxJejPP8TSgXMKFaDa+2HleTycTBYSoErAZSWpQ0NqF9zBadjsJRVatQuPkTDrwL
# eWibiyOipK9fcNoQpl5ll5H9EG668YJR3fqX9o0TQTkOmxXIL3IJ0UxdpyDpLEkt
# tBG6Y5wAdpF2dQX2phrfFNVY54JOGtuBkNGMSiLFzTkBA1fOlA6ICMYjB8xIFxVv
# rN1tYojCrqYkKMOjwWQz5X8zAgMBAAGjggGZMIIBlTAOBgNVHQ8BAf8EBAMCB4Aw
# TAYDVR0gBEUwQzBBBgkrBgEEAaAyATIwNDAyBggrBgEFBQcCARYmaHR0cHM6Ly93
# d3cuZ2xvYmFsc2lnbi5jb20vcmVwb3NpdG9yeS8wCQYDVR0TBAIwADATBgNVHSUE
# DDAKBggrBgEFBQcDAzBCBgNVHR8EOzA5MDegNaAzhjFodHRwOi8vY3JsLmdsb2Jh
# bHNpZ24uY29tL2dzL2dzY29kZXNpZ25zaGEyZzIuY3JsMIGQBggrBgEFBQcBAQSB
# gzCBgDBEBggrBgEFBQcwAoY4aHR0cDovL3NlY3VyZS5nbG9iYWxzaWduLmNvbS9j
# YWNlcnQvZ3Njb2Rlc2lnbnNoYTJnMi5jcnQwOAYIKwYBBQUHMAGGLGh0dHA6Ly9v
# Y3NwMi5nbG9iYWxzaWduLmNvbS9nc2NvZGVzaWduc2hhMmcyMB0GA1UdDgQWBBTN
# GDddiIYZy9p3Z84iSIMd27rtUDAfBgNVHSMEGDAWgBQZSrha5E0xpRTlXuwvoxz6
# gIwyazANBgkqhkiG9w0BAQsFAAOCAQEAAApsOzSX1alF00fTeijB/aIthO3UB0ks
# 1Gg3xoKQC1iEQmFG/qlFLiufs52kRPN7L0a7ClNH3iQpaH5IEaUENT9cNEXdKTBG
# 8OrJS8lrDJXImgNEgtSwz0B40h7bM2Z+0DvXDvpmfyM2NwHF/nNVj7NzmczrLRqN
# 9de3tV0pgRqnIYordVcmb24CZl3bzpwzbQQy14Iz+P5Z2cnw+QaYzAuweTZxEUcJ
# bFwpM49c1LMPFJTuOKkUgY90JJ3gVTpyQxfkc7DNBnx74PlRzjFmeGC/hxQt0hvo
# eaAiBdjo/1uuCTToigVnyRH+c0T2AezTeoFb7ne3I538hWeTdU5q9jGCBLcwggSz
# AgEBMHAwWjELMAkGA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2Ex
# MDAuBgNVBAMTJ0dsb2JhbFNpZ24gQ29kZVNpZ25pbmcgQ0EgLSBTSEEyNTYgLSBH
# MgISESENFrJbjBGW0/5XyYYR5rrZMAkGBSsOAwIaBQCgeDAYBgorBgEEAYI3AgEM
# MQowCKACgAChAoAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQB
# gjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBSgnaQJB4eJ6uBY
# awmN/BtkqVcLtDANBgkqhkiG9w0BAQEFAASCAQC8vfwzQNBLBxrBuqo0sY8k6Ajr
# ajiNncnPPYiqewnExAqLxFcbSV0qNei1A6eE6ULLPh3TtAwOmqZo2zNAoZGdeKZI
# 7gItpu4agDBUI8i7ESk2sVt3aFCCXW1OB4i+m902IHFgcX52uHIO9ZRebwgkP5HZ
# FnILClx8YSdU8SNkjYibB1l9mmt5+AAgdZFvY4Tr9RVwVFSDyVYoYEzZCLnXK3cX
# Fdr9ut9VNHcRwWvz3bi5O2be2bNvoRhXBvG8eJ1VpF4sIxVml61lfq17KGD3gJ7L
# FsisslZfW0k1YHzu433T3jHtizsqB+xYiSpZfOq1zr3DzDgW5aIOl3Q6Q1IjoYIC
# ojCCAp4GCSqGSIb3DQEJBjGCAo8wggKLAgEBMGgwUjELMAkGA1UEBhMCQkUxGTAX
# BgNVBAoTEEdsb2JhbFNpZ24gbnYtc2ExKDAmBgNVBAMTH0dsb2JhbFNpZ24gVGlt
# ZXN0YW1waW5nIENBIC0gRzICEhEhBqCB0z/YeuWCTMFrUglOAzAJBgUrDgMCGgUA
# oIH9MBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTE1
# MDcxMTA5MDUwMVowIwYJKoZIhvcNAQkEMRYEFM9W8MdAZTO/mbt8Ue1vu0AvQDz7
# MIGdBgsqhkiG9w0BCRACDDGBjTCBijCBhzCBhAQUs2MItNTN7U/PvWa5Vfrjv7Es
# KeYwbDBWpFQwUjELMAkGA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYt
# c2ExKDAmBgNVBAMTH0dsb2JhbFNpZ24gVGltZXN0YW1waW5nIENBIC0gRzICEhEh
# BqCB0z/YeuWCTMFrUglOAzANBgkqhkiG9w0BAQEFAASCAQCAc1j1p0tcWzUI/4PB
# RseXTwlbjthUWTspnrZY7At/wbDKX4f6tGpOz+Bsbcs5aiHV1NcKZtkRhDRKAXRI
# W0C5ON86lU154jPxDN3kTBUj2phQYCj0uo8f9vR9jpShT991/mf6fSVQf1dQKMZV
# qOiKoVK9o4wI9eeBeKTLsMU8E6fYESjwcfNyRnVoVhJVp6jjgajwj+wkv2SiNttE
# 8TbdOJjoSsPTEuWiliw78GcSPAJggcdkQf7sdA0VYVNhUkRetGCGqjF0jkc5951b
# amepS6/X4ZJKuKDz+JMFJP5qtwhynYTruqNnQhM3OBuIEyOd/inO1AwIvMQDbyDA
# ODAl
# SIG # End signature block
