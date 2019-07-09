#Please read the comments.You may need to change the snapshot prefix to avoid any of your existing snapshots
#getting over written.
#You will also need to remove the existing snapshots from source and target subscriptions on the second runs
param (
    [string] $sourceSubscriptionId = "",
    [string] $sourceResourceGroupName = "",
    [string] $sourceVMName = "",
    [string] $targetSubscriptionId = "",
    [string] $targetResourceGroupName = "",
    [string] $targetVMName = "",
    [string] $snapshotNameSuffix = "_Snapshot",
    [string] $diskNameSuffix = "_FromSnapshot",
    [string] $keepTheDisks = "false"
)


# Set the context to the subscription Id where snapshot exists
Select-AzSubscription -SubscriptionId $sourceSubscriptionId

# Setting the location
$location = (Get-AzureRmResourceGroup -Name $sourceResourceGroupName).location

#Getting the VM details
$sourceVM = get-azurermvm `
-ResourceGroupName $sourceResourceGroupName `
-Name $sourceVMName

# Getting the Data Disk Disk_Names Source VM Storage profile
$DiskNames= $sourceVM.StorageProfile.DataDisks.Name

# Getting the Disk objects using Disk names
$Disks=@()
$DiskNames | ForEach-Object {
    $Disks += Get-AzureRmDisk -ResourceGroupName $sourceResourceGroupName -DiskName $_
}

# #Removing existing snapshots if any.Re Enable if needed

# $Jobs=@()
# $Disks | ForEach-Object {
#     $Jobs+=Remove-AzureRmSnapshot -ResourceGroupName $sourceResourceGroupName -SnapshotName ($_.Name.toString()+$snapshotNameSuffix) -Force -Asjob
# }

# $tc=0
# while ($Jobs.State.Contains("Running")){
#     $tc=$tc+2
#     "Deleting Snapshots  with suffix '"+$snapshotNameSuffix+"' from the resource group "+$sourceResourceGroupName+" Expired "+$tc.toString()+" seconds"
#     sleep 2
# }

#Creating new snapshots
$Jobs=@()
$Disks| ForEach-Object {
    $Snapshot_Config = New-AzureRmSnapshotConfig -SourceUri $_.Id -CreateOption Copy -Location $location -SkuName Standard_LRS
    $Jobs+=New-AzureRmSnapshot -Snapshot $Snapshot_Config -SnapshotName ($_.Name.toString()+$snapshotNameSuffix) -ResourceGroupName $sourceResourceGroupName -Asjob
}

$tc=0
while ($Jobs.State.Contains("Running")){
    $tc=$tc+2
    "Waiting for new snap shots to finish "+$tc.toString()+" seconds"
    sleep 2
}

# Collecting Snapshots to an Array to be used later
$Snapshots=@()
$Disks | ForEach-Object {  
    $Snapshots+= Get-AzureRmSnapshot -ResourceGroupName $sourceResourceGroupName -SnapshotName ($_.Name.toString()+$snapshotNameSuffix)
}

###########################Target vm operations #####################
#Set the context to the subscription Id where snapshot will be copied to
#If snapshot is copied to the same subscription then the following block will be skipped
if ($sourceSubscriptionId -ne $targetSubscriptionId){
    Select-AzSubscription -SubscriptionId $targetSubscriptionId
    $Jobs=@()
    $Snapshots| ForEach-Object {
        $snapshotConfig = New-AzSnapshotConfig -SourceResourceId $_.Id -Location $_.Location -CreateOption Copy 
        #Updating the Snapshot array
        $Jobs+=New-AzSnapshot -Snapshot $snapshotConfig -SnapshotName $_.Name -ResourceGroupName $targetResourceGroupName -Asjob
    }
}
$Snapshots=@()
Get-AzureRmSnapshot -ResourceGroupName $targetResourceGroupName | Foreach-Object {
    if ($_.Name.Contains($sourceVMName) -and $_.Name.Contains($snapshotNameSuffix)){$Snapshots+=$_}
    }


# Detaching existing data disks from Target vm
$targetVM = get-azurermvm -ResourceGroupName $targetResourceGroupName -Name $targetVMName
$tDisk_Names=$targetVM.StorageProfile.DataDisks.Name
$targetVM.StorageProfile.DataDisks | ForEach-Object  {
    $targetVM=Remove-AzureRmVMDataDisk  -VM $targetVM -DataDiskNames $_.Name
}
#Update the VM Object to commit the changes
Update-AzureRmVM -ResourceGroupName $targetResourceGroupName -VM $targetVM

#Deleting the disks if required aftert detachig it from the VM
if($keepTheDisks -ne 'true'){
    $jobs=@()
    $tDisk_names | ForEach-Object {
        $jobs+=Remove-AzureRmDisk -ResourceGroupName $targetResourceGroupName -DiskName $_ -Force -AsJob
    }
    $tc=0
    while ($jobs.State.Contains("Running")){
        $tc=$tc+2
        "Deleting Deatched Disks from the resource group-"+$targetResourceGroupName+". "+$tc.toString()+" seconds"
        sleep 2
    }
}

#Creating Disks from Snapshots
$location = (Get-AzureRmResourceGroup -Name $targetResourceGroupName).location
$AccountType = 'Premium_LRS'
$jobs=@()
$Snapshots | ForEach-Object {
    $diskConfig = New-AzureRmDiskConfig -AccountType $AccountType -Location $_.Location -SourceResourceId $_.Id -CreateOption Copy 
    $jobs+= New-AzureRmDisk -Disk $diskConfig -ResourceGroupName $TargetresourceGroupName -DiskName (($_.Name -replace $snapshotNameSuffix,$diskNameSuffix) -replace $sourceVMName,$targetVMName)  -AsJob
}

$tc=0
while ($jobs.State.Contains("Running")){
    $tc=$tc+2
    "Waiting for Disk create to finish. "+$tc.toString()+" seconds"
    sleep 2  
}

# Finding the Disks using  disk suffix names from target resource group
$Disklist=Get-AzureRmDisk -ResourceGroupName $TargetresourceGroupName
$Disks=@()
$Disklist | ForEach-Object {
    if($_.Name.contains($diskNameSuffix) -and $_.Name.contains($targetVMName) ){
        $Disks += $_
    }
}

# Attaching the newly created disks to target VM
$targetVM = get-azurermvm -ResourceGroupName $targetResourceGroupName -Name $targetVMName
# Finding the available lun numbers
$Lun_numbers=@()
$Disc_counter= $Disks.count
$counter=0
while ($Disc_counter -ne 0) {
    if ($targetVM.StorageProfile.DataDisks.Lun -notcontains($counter)){
        $Lun_numbers += $counter
        $Disc_counter--    
    }
    $counter++
}
# Attaching the discs
$counter=0
$Disks | ForEach-Object {
    $targetVM=Add-AzureRmVMDataDisk -VM $targetVM -Name $_.Name -CreateOption Attach -ManagedDiskId $_.Id -Lun $Lun_numbers[$counter] -Caching 'ReadOnly'
    $counter++
}
