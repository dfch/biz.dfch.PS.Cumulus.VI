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

