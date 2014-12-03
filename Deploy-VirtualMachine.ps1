function Deploy-VirtualMachine {
<#
.SYNOPSIS

Deploys a new virtual machinee

.NOTES

See module manifest for required software versions and dependencies:
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
		$VM = Get-VM -Name $Name -ea SilentlyContinue;
		if( $VM -and ( ( 'VirtualMachineImpl' -eq $VM.GetType().Name) -or (('Array') -eq $VM.GetType().BaseType.Name ) ))
		{
			$e = New-CustomErrorRecord -m ( 'VM with same name already exists: {0}' -f $Name )
            throw($gotoError);
		}
		
		Log-Debug -fn $fn -msg ( "No VM's with same name exist: {0}" -f $Name )
		
		#Define destination Resource  Pool
		if(  ($null -ne $ResourcePoolName ) -and (('String') -eq $ResourcePoolName.GetType().Name  ) -and (0 -lt $ResourcePoolName.length) )
		{
			Log-Debug -fn $fn -msg ( "ResourcePoolName provided - Check if Resource Pool: {2} exists in cluster: {1}" -f $Name, $ClusterName, $ResourcePoolName );
			$RP = Get-Cluster -Name $ClusterName | Get-ResourcePool -name $ResourcePoolName -ea SilentlyContinue; 
			if(($null -eq $RP) -or ('ResourcePoolImpl' -ne $RP.getType().name)){
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
		{	Log-Debug -fn $fn -msg ( "Create Diskconfig on VM: {0}" -f $Name )
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
		Log-Error -fn $fn -msg  ("Error occurred during VM Video Memory Size {0} " -f $_.Exception.Message )
		return $null;
	}
} # function

if($MyInvocation.ScriptName) { Export-ModuleMember -Function Deploy-VirtualMachine; } 


# SIG # Begin signature block
# MIIW3AYJKoZIhvcNAQcCoIIWzTCCFskCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUw9Y4fmFYyu5qi8VByop011Uy
# oyagghGYMIIEFDCCAvygAwIBAgILBAAAAAABL07hUtcwDQYJKoZIhvcNAQEFBQAw
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
# AQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBQS+eNgVskZWnjSvxjW
# xVwM6U2DHzANBgkqhkiG9w0BAQEFAASCAQBQU1Ryz1m68W/50Z6I7TiKv/qesp42
# fgk2Kqu1GAqs6gfb8r+KYY18OJyl6Ra09A93pZgMg1ic1bw2MnJ5qrERH8ncW88K
# gHR+5Lf9BHgjaaeVm5/OGCSw/k0sPC1gO5pqB8T2vsy7R0MAqdO8e/jawevKTgXT
# vx6URhdMMpX5gzIfFkf/CXXPAfDNqn0WO8rc21Bdisy5h/3Vp52a5T8/mVvax22b
# /FPnDTozXdp3TscBhP3btce+DgBCb5JwZSGIbmGyxvEukpuh6X0H5v4SoEJLtolJ
# uS/xgPdC6Pq5n5811tTWpEa3qnPp2PUEzcPbekD3GDYXDAmkr9cpDhAgoYICojCC
# Ap4GCSqGSIb3DQEJBjGCAo8wggKLAgEBMGgwUjELMAkGA1UEBhMCQkUxGTAXBgNV
# BAoTEEdsb2JhbFNpZ24gbnYtc2ExKDAmBgNVBAMTH0dsb2JhbFNpZ24gVGltZXN0
# YW1waW5nIENBIC0gRzICEhEhQFwfDtJYiCvlTYaGuhHqRTAJBgUrDgMCGgUAoIH9
# MBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTE0MTIw
# MzA0MTQxNFowIwYJKoZIhvcNAQkEMRYEFKugRBDkT2Sm36G9mP+Rap2x1PbNMIGd
# BgsqhkiG9w0BCRACDDGBjTCBijCBhzCBhAQUjOafUBLh0aj7OV4uMeK0K947NDsw
# bDBWpFQwUjELMAkGA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2Ex
# KDAmBgNVBAMTH0dsb2JhbFNpZ24gVGltZXN0YW1waW5nIENBIC0gRzICEhEhQFwf
# DtJYiCvlTYaGuhHqRTANBgkqhkiG9w0BAQEFAASCAQCg5c2EuCKk5P5tx+DBSzZa
# fFnwTOlaJy2CA2JH8It5/K74kCxyFPUpfq4fpdfHPJXsV3r9DN2wkMW5f7892UrL
# YrpmqjYe5dpb6c/AYaO8kZ37obRKdAx64KLJnhYGbmv11lbpZceAQ3xD8u0OFCjV
# h52KjMJRbX7Lp5M2iKRNNA1kFW7H/zPV+r43JmafR2TR6WYr/gqoUBNvnonVNgyL
# pUt+JFG7q7pxKkzTKErO4NktBUxP5YSyPazUpvDVoVONBsDhyIwIEDpVbaVzPaDU
# adTqPCAX0kmb58bL6HUKulhim71UgJuf9GDBFGNcflRv8M1VJuGr0GaljKbwrdt1
# SIG # End signature block
