Param(
    [parameter(Mandatory=$true)]
    [object]$configData,
    [string]$vm
)


# Connect to Azure account   
$Conn = Get-AutomationConnection -Name AzureRunAsConnection
Connect-AzureRmAccount -ServicePrincipal -Tenant $Conn.TenantID `
    -ApplicationID $Conn.ApplicationID -CertificateThumbprint $Conn.CertificateThumbprint


    $subscriptionId = $configData.subscriptionId
    $storageAccountName = $configData.StorageAccountName
    $containerName = $configData.scriptPath
    $scriptName = $configData.scriptName
    $scriptArgument = $configData.scriptArgument
    $resourceGroup = $configData.resourceGroup
    $virtualMachines = $configData.VirtualMachines
    $successVMList=@()
    $failedVMList=@()
    $nogpuVMList=@()

    $path = "C:\Scripts"
        If(!(test-path $path))
        {
            New-Item -ItemType Directory -Force -Path $path
        }

$filePath = Join-Path -Path '$path'

    
    Set-AzureRmContext -SubscriptionId $subscriptionId

    $storageAccount = Get-AzureRmStorageAccount | where {$_.StorageAccountName -eq $configData.StorageAccountName}
    $k = (Get-AzureRmStorageAccountKey -ResourceGroupName $storageaccount.ResourceGroupName -Name $storageaccount.StorageAccountName).Value[0]            
    
    $blob = (Get-AzureStorageBlob -Context $storageAccount.Context -Container $containerName -Blob $scriptName).ICloudBlob.DownloadText()
    $blob | Out-File $filePath -Force

    $azVm = Get-AzurermVM -ResourceGroupName $resourceGroup -Name $vm


    Set-AzureRmVMCustomScriptExtension -ResourceGroupName $resourceGroup `
    -VMName $vm `
    -FileName "$filePath\$scriptName" `
    -ContainerName $containername `
    -StorageAccountName $storageAccount.StorageAccountName `
    -StorageAccountKey $k `
    -Run "$scriptName" `
    -Argument "$scriptArgument" `
    -Name "CheckGPUDriver" `
    -TypeHandlerVersion "1.1" `
    -Location $azVm.Location

    Get-AzureRmVMCustomScriptExtension -ResourceGroupName $resourceGroup -VMName $vm -Name "CheckGPUDriver"

$output = Get-AzureRmVMDiagnosticsExtension -ResourceGroupName $rgname `
             -VMName $vm `
             -Name "CheckGPUDriver" `
             -Status

$output.SubStatuses[0]

$output.SubStatuses[0].Message

if ($output.SubStatuses[0].Message -eq "CM_PROB_FAILED") {
$failedVMList += $vmName
Write-Output "$vmName : Returncode - CM_PROB_FAILED"
} elseif ($output.SubStatuses[0].Message -eq "CM_PROB_NONE") {
$successVMList += $vmName
Write-Output "$vmName : Returncode - CM_PROB_NONE"
} elseif ($output.SubStatuses[0].Message -eq "NO_GPU_FOUND") {
$nogpuVMList += $vmName
Write-Output "$vmName : Returncode - NO_GPU_FOUND"
}

foreach($vm in $failedVMList)
{
    Write-Output "$vm : GPU Driver Check failed...CM_PROB_FAILED...Restarting..."

    Get-AzureRmVM -ResourceGroupName $rgname -Name $vm | Stop-AzureRmVM -Force

    sleep 5

    Get-AzureRmVM -ResourceGroupName $rgname -Name $vm | Start-AzureRmVM
}

foreach($vm in $successVMList)
{
    Write-Output "$vm : GPU Driver Check is success...CM_PROB_NONE"
}

foreach($vm in $nogpuVMList)
{
    Write-Output "$vm : No GPU Driver is installed..."
}

