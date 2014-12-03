$report = @()
$clusterName = "*"
$report = foreach($cluster in Get-Cluster -Name $clusterName){
    $esx = $cluster | Get-VMHost 
    $ds = Get-Datastore -VMHost $esx | where {$_.Type -eq "VMFS" -and $_.Extensiondata.Summary.MultipleHostAccess}
    $rp = Get-View $cluster.ExtensionData.ResourcePool
    New-Object PSObject -Property @{
        VCname = $cluster.Uid.Split(':@')[1]
        DCname = (Get-Datacenter -Cluster $cluster).Name
        Clustername = $cluster.Name
        "CPU Total Capacity" = $rp.Runtime.Cpu.MaxUsage
        "CPU Reserved Capacity" = $rp.Runtime.Cpu.ReservationUsed
        "CPU Available Capacity" = $rp.Runtime.Cpu.MaxUsage - $rp.Runtime.Cpu.ReservationUsed
        "Memory Total Capacity" = $rp.Runtime.Memory.MaxUsage
        "Memory Reserved Capacity" = $rp.Runtime.Memory.ReservationUsed
        "Memory Available Capacity" = $rp.Runtime.Memory.MaxUsage - $rp.Runtime.Memory.ReservationUsed
    }
}

$report | Export-Csv "C:\Cluster-Report-test.csv" -NoTypeInformation –UseCulture
