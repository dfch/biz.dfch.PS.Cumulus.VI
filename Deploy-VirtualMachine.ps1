function Deploy-VirtualMachine {
<#
.SYNOPSIS

Deploys a new virtual machinee

.NOTES

See module manifest for required software versions and dependencies at:
http://dfch.biz/biz/dfch/PS/Cumulus/VI/biz.dfch.PS.Cumulus.VI.psd1/


#>
PARAM
(
	[Parameter(Mandatory = $true, Position = 0)]
	[ValidateNotNullOrEmpty()]
	[string] $Name
	,
	[Parameter(Mandatory = $true, Position = 1)]
	[ValidateNotNullOrEmpty()]
	[string] $ClusterName
	,
	[Parameter(Mandatory = $false, Position = 2)]
	[string] $ResourcePoolName = $null
	,
	[Parameter(Mandatory = $true, Position = 3)]
	[ValidateNotNullOrEmpty()]
	[System.Int64] $NumCpu
	,
	[Parameter(Mandatory = $false, Position = 4)]
	[ValidateRange(1,64)]
	[int64] $NumCoresPerSocket
	,
	[Parameter(Mandatory = $true, Position = 5)]
	[ValidateNotNullOrEmpty()]
	[System.Int64] $MemoryMB
	,
	[Parameter(Mandatory = $true, Position = 6)]
	[ValidateNotNullOrEmpty()]
	[string] $GuestId
	,
	[Parameter(Mandatory = $false, Position = 7)]
	[ValidateNotNullOrEmpty()]
	[Array] $diskConfigs
	,
	[Parameter(Mandatory = $false, Position = 8)]
	[ValidateNotNullOrEmpty()]
	[Array] $nicConfigs
	,
	[Parameter(Mandatory = $true, Position = 9)]
	[ValidateNotNullOrEmpty()]
	[switch] $Floppy = $false
	,
	[Parameter(Mandatory = $true, Position = 10)]
	[ValidateNotNullOrEmpty()]
	[switch] $CD = $false
	,
	[Parameter(Mandatory = $false, Position = 11)]
	[ValidateNotNullOrEmpty()]
	[ValidateSet("manual","upgradeAtPowerCycle")]
	[ValidateNotNullOrEmpty()]
	[String] $UpgradePolicy
	,
	[Parameter(Mandatory = $false, Position = 12)]
	[ValidateNotNullOrEmpty()]
	[Boolean] $SyncTimeWithHost = $false
	,
	[Parameter(Mandatory = $false, Position = 13)]
	[ValidateNotNullOrEmpty()]
	[Boolean] $vCpuHotAdd
	,
	[Parameter(Mandatory = $false, Position = 14)]
	[ValidateNotNullOrEmpty()]
	[Boolean] $MemHotAdd
	,
	[Parameter(Mandatory = $false, Position = 15)]
	[ValidateNotNullOrEmpty()]
	[ValidateRange(2,128)]
	[int64] $VideoMemoryMB
	
)
	
	try
	{
		$datBegin = [datetime]::Now;
		[string] $fn = $MyInvocation.MyCommand.Name;
		Log-Debug -fn $fn -msg ("CALL")
		
		Log-Debug -fn $fn -msg ('VMName:{0} ClusterName:{1} RP:{2} NumCPU:{3} MemoryMB:{4} GuestID:{5} Diskconfigs:{6} netConfigs:{7} Floppy:{8} CD:{9} UpgradePolicy:{10} SyncTimeWithHost:{11} vCpuHotAdd:{12} MemHotAdd:{13} $VideoMemoryMB:{14}' -f $Name, $ClusterName, $ResourcePoolName,  $NumCpu, $MemoryMB, $GuestId, $diskConfigs, $nicConfigs, $Floppy, $CD, $UpgradePolicy, $SyncTimeWithHost, $vCpuHotAdd, $MemHotAdd, $VideoMemoryMB )
		
		Log-Debug -fn $fn -msg ( "Check if VM already exists: {0}" -f $Name )
		$VM = Get-VM -Name $Name -ea SilentlyContinue | Select -First 1;
		if( $VM )
		{
			$e = New-CustomErrorRecord -m ( 'VM with same name already exists: {0}' -f $Name ) -cat ResourceExists -o $VM;
            throw($gotoError);
		}
		
		Log-Debug -fn $fn -msg ( "No VM's with same name exist: {0}" -f $Name )
		
		#Define destination Resource  Pool
		if(  ($null -ne $ResourcePoolName ) -and (('String') -eq $ResourcePoolName.GetType().Name  ) -and (0 -lt $ResourcePoolName.length) )
		{
			Log-Debug -fn $fn -msg ( "ResourcePoolName provided - Check if Resource Pool: {2} exists in cluster: {1}" -f $Name, $ClusterName, $ResourcePoolName );
			$RP = Get-Cluster -Name $ClusterName | Get-ResourcePool -name $ResourcePoolName -ea SilentlyContinue; 
			if(($null -eq $RP) -or ('ResourcePoolImpl' -ne $RP.getType().name))
			{
				$e = New-CustomErrorRecord -m ( 'Failed to retrieve ResourcePool object: {0}' -f $ResourcePoolName )
				throw($gotoError);
			}
		} 
		else 
		{
			Log-Debug -fn $fn -msg ( "No ResourcePoolName provided - Cluster: {1} will be the target resource Pool: {0}" -f $Name, $ClusterName );
			$RP = Get-Cluster -Name $ClusterName -ea SilentlyContinue;
			if(($null -eq $RP) -or ('ClusterImpl' -ne $RP.getType().name))
			{
				$e = New-CustomErrorRecord -m ( 'Failed to retrieve cluster object: {0}' -f $ClusterName )
				throw($gotoError);
			}
		}
		<#
			$VMHost = Get-DestinationHost -ClusterName $ClusterName
			if(($null -eq $VMHost) -or ('VMHostImpl' -ne $VMHost.getType().name))
			{
				$e = New-CustomErrorRecord -m ( 'Failed to determine a suiteable host in cluster: {0}' -f $ClusterName )
				throw($gotoError);
			}
		
		
		Log-Debug -fn $fn -msg ( "Create Base VM: {0}" -f $Name )	
		$VM = New-VM -Name $Name -ResourcePool $RP -NumCpu $NumCpu -MemoryMB $MemoryMB -NetworkName $NetworkName -DiskMB $DiskMB -GuestId $GuestId -DiskStorageFormat $DiskStorageFormat -Datastore $ds
		#>
		#Check if datastore placement is required
		Log-Debug -fn $fn -msg ( "Check if datastore placement is required for VM: {0}" -f $Name )
		if( $diskConfigs -and $diskConfigs[0].DatastoreName -and ( 0 -lt $diskConfigs[0].DatastoreName.length))
		{
			$dsName = $diskConfigs[0].Datastorename
			#Avoid Duplicate Names
			$ds = Get-Cluster -Name $ClusterName | Get-Datastore -Name $dsName -ErrorAction Stop
			if( $ds -and $ds -isnot [Array] )
			{
				Log-Debug -fn $fn -msg ( "VM: {0} - Target datastore given {1}" -f $Name, $dsName  )
				$VM = New-VM -Name $Name -ResourcePool $RP -NumCpu $NumCpu -MemoryMB $MemoryMB  -GuestId $GuestId -Floppy:$Floppy -CD:$CD -Datastore $ds
			}
		} 
		else 
		{
			Log-Debug -fn $fn -msg ( "No datastore placement is required for VM: {0}" -f $Name )
			$VM = New-VM -Name $Name -ResourcePool $RP -NumCpu $NumCpu -MemoryMB $MemoryMB  -GuestId $GuestId -Floppy:$Floppy -CD:$CD
		}	
		
		
		#Check if created object is valid
		if( ($null -eq $VM) -or ('VirtualMachineImpl' -ne $VM.getType().name))
		{
			$e = New-CustomErrorRecord -m "Failed to find the created VM."
			throw($gotoError);
		}
		
		#Temp remove disk/nick, since base vm cannot be created without, but cannot be created with all possible parameters
		Log-Debug -fn $fn -msg ( "Get disk to delete on base VM: {0}" -f $Name )
		$delDisks = $VM | Get-Harddisk;
		if( ($null -ne $delDisks) -and ($delDisks.count -eq 1) -and ( 'HardDiskImpl' -eq $delDisks.GetType().baseType.Name ) )
		{
				Log-Debug -fn $fn -msg ( "Delete Disk: {1} Cap: {3} File: {2} on base VM: {0}" -f $Name, $delDisks.Name, $delDisks.filename, $delDisks.CapacityGB)
				$delDisks | Remove-HardDisk -DeletePermanently -Confirm:$false
		}
		
		Log-Debug -fn $fn -msg ( "Get nics to delete on base VM: {0}" -f $Name )
		$delNics = $VM | Get-NetworkAdapter;
		if( ($null -ne $delNics) -and ($delNics.count -eq 1) -and ( 'NetworkAdapterImpl' -eq $delNics.GetType().Name ) )
		{	
			Log-Debug -fn $fn -msg ( "Delete Nic: {1} Type: {2} NetName: {3} Mac: {4} on base VM: {0}" -f $Name,$delNics.Name, $delNics.type, $delNics.networkname, $delNics.MacAddress )
			$delNics | Remove-NetworkAdapter -confirm:$false;
		}
			
		
		#Create Diskconfig
		#Get first disk info:
		if( ($null -ne $diskConfigs) -and (0 -lt $diskConfigs.count) )
		{	
			Log-Debug -fn $fn -msg ( "Create Diskconfig on VM: {0}" -f $Name )
			$res = Set-VMDiskConfig -VMName $VM.Name -DiskConfigs $diskConfigs
			if( $null -eq $res )
			{
				$e = New-CustomErrorRecord -m ( 'VM diskConfig failed: {0}' -f $Name )
				throw($gotoError);
			}
		}
		
		#Get first nic info:
		if( ($null -ne $nicConfigs) -and (0 -lt $nicConfigs.count) )
		{
			Log-Debug -fn $fn -msg ( "Create Netconfig on VM: {0}" -f $Name )
			$res = Set-VMNicConfig -VMName $VM.Name -NicConfigs $nicConfigs
			if( $null -eq $res )
			{
				$e = New-CustomErrorRecord -m ( 'VM nicConfig failed: {0}' -f $Name )
				throw($gotoError);
			}
		}
		
		#Adjust VMware Tools Upgrade Policy if necessary
		if ( $UpgradePolicy )
		{	
			Log-Debug -fn $fn -msg ("{0}: Adjust VMware Tools Upgrade Policy: {1}" -f $Name, $UpgradePolicy )
			Set-VMwareToolsUpgradePolicy -VM $VM -UpgradePolicy $UpgradePolicy
		}

		#Adjust VMware Tools Time Synch if necessary
		if ( $SyncTimeWithHost )
		{
			Log-Debug -fn $fn -msg ("{0}: Adjust VMware Tools Time Synch: {1}" -f $Name, $SyncTimeWithHost )
			Set-VMwareToolsSyncTimeWithHost -VM $VM -sync $SyncTimeWithHost
		}

		#Adjust VM CPU Hot Add Capabilities if necessary
		if( $vCpuHotAdd )
		{ 
			Log-Debug -fn $fn -msg ("{0}: Adjust VM CPU Hot Add Capabilities: {1}" -f $Name, $vCpuHotAdd )
			Set-vCpuHotAdd -VM $VM -enable $vCpuHotAdd
		}

		#Adjust VM Memory Hot Add Capabilities if necessary
		if( $MemHotAdd )
		{ 	
			Log-Debug -fn $fn -msg ("{0}: Adjust VM Memory Hot Add Capabilities: {1}" -f $Name, $MemHotAdd)
			Set-MemHotAdd -VM $VM -enable $MemHotAdd
		}

		#Adjust VM Video Memory Size if necessary
		if( $VideoMemoryMB )
		{
			Log-Debug -fn $fn -msg ("{0}: Adjust VM Video Memory Size: {1}" -f $Name, $VideoMemoryMB )
			Set-VMVideoMemory -VM $VM -VideoMemoryMB $VideoMemoryMB
		}
		
		#Adjust VM numCores if necessary
		if( ($null -ne $NumCoresPerSocket) -and ( 1 -lt $NumCoresPerSocket) )
		{
			Log-Debug -fn $fn -msg ("{0}: Adjust NumCores Ratio: NumCpu: {1} NumCores: {2}" -f $Name, $NumCpu, $NumCoresPerSocket )
			$res = Set-vCpuCoresPerSocket -NumCpu $NumCpu -NumCoresPerSocket $NumCoresPerSocket -VM $VM
			if( ( $null -eq $res) -or ($false -eq $res))
			{
				$e = New-CustomErrorRecord -m 'Failed to configure NumCoresPerSocket'
				throw($gotoFailure);
			}
		}
		
		#return refreshed object
		return ( $VM = Get-VM -name $VM.Name )
	}
	catch
	{
		Log-Error -fn $fn -msg  ("Error occurred while setting parameters for VM. Exception Message: '{0}'" -f $_.Exception.Message )
		return $null;
	}
} # function

if($MyInvocation.ScriptName) { Export-ModuleMember -Function Deploy-VirtualMachine; } 


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
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUaYlE3lxmhDF2+jPd75loHBM1
# McCgghHCMIIEFDCCAvygAwIBAgILBAAAAAABL07hUtcwDQYJKoZIhvcNAQEFBQAw
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
# gjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBQAlQ0EPBh+v8Jn
# CpAf09oz7WLN+jANBgkqhkiG9w0BAQEFAASCAQBqFFmjT54el8OHpUrrJVqI4uEZ
# rzS1ejZd8lM+4yo4LZFbTYRfHMYYDxCXSqjFEOxTEefZ+2mSxjNKWcWLgW311aMO
# I7boId3g6Nx+KoczMa3qjUOz4+e5rZkaNGo4vZziwVTW2mfSYcQniP5k+Z/7qCTI
# 1N/YOAsopzmzIhH+T5FmVAUhQaeTw2aVGYe4HWArjT10S8jFhWzESccSdboBXq2E
# ngAEXJUuCHIqyIX6WZeT9I1xVdIqMSbIlUUh7IbP5qJpJiyO7d1hx5e/ERT+4ASh
# CdA+WKJ6OmZt+y4MCM0uD8mzxMVKDUfsSlya8gUXqb2NjB8dbBRsMTNd//uMoYIC
# ojCCAp4GCSqGSIb3DQEJBjGCAo8wggKLAgEBMGgwUjELMAkGA1UEBhMCQkUxGTAX
# BgNVBAoTEEdsb2JhbFNpZ24gbnYtc2ExKDAmBgNVBAMTH0dsb2JhbFNpZ24gVGlt
# ZXN0YW1waW5nIENBIC0gRzICEhEhBqCB0z/YeuWCTMFrUglOAzAJBgUrDgMCGgUA
# oIH9MBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTE1
# MDcxMTA5MDUwMVowIwYJKoZIhvcNAQkEMRYEFKf5MEQDt2KDb2AZqeVoP7TEVPsJ
# MIGdBgsqhkiG9w0BCRACDDGBjTCBijCBhzCBhAQUs2MItNTN7U/PvWa5Vfrjv7Es
# KeYwbDBWpFQwUjELMAkGA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYt
# c2ExKDAmBgNVBAMTH0dsb2JhbFNpZ24gVGltZXN0YW1waW5nIENBIC0gRzICEhEh
# BqCB0z/YeuWCTMFrUglOAzANBgkqhkiG9w0BAQEFAASCAQAXG7lCTHrk+Ibasbws
# JAM1pKjgmXqkVO6RiZWRqUEg4fbZ70Yx5qmkuCoXm7Gu9XcCuC3NxEOI5Bsaidt4
# KX0sELxIHOf/VzxTuHVjUYdeoGIO3fZ0EfWXTCCnTFNLldFp8wKfQpK4QOvsWzje
# 2MAMl0WrdY2nNn9IMgwyQ78M61JVZ8h+FjCSriJHXNy/9ZQKPhN81+MJlTjT5D1V
# QHYqyenj5WhQkm6f4019/oTfDg+K7gtEcIbSNEK3yzgWCNstjEnt2DjmNVZqMYy5
# Rb7ct+MFT9tVGPna27uLHlBY7LHRTkyl28Z8ot4ZT5v1rykhuyZJ8gVeHSfOWGxC
# dLCb
# SIG # End signature block
