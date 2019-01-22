Param(
    [parameter(Mandatory=$true)]
    [object]$configData
)


# Connect to Azure account   
$Conn = Get-AutomationConnection -Name AzureRunAsConnection
Connect-AzureRmAccount -ServicePrincipal -Tenant $Conn.TenantID `
    -ApplicationID $Conn.ApplicationID -CertificateThumbprint $Conn.CertificateThumbprint



    #Get the name of the storage account that hosts the master configuration


    Set-AzureRmContext -SubscriptionId $subscriptionId

$runbookName = "Code10EChkMain"

foreach ($vm in $virtualMachines)
{

    $RBParams = @{"configData" = $configData; "vm" = $vm}
    Start-AutomationRunbook -Name $runbookName -Parameters $RBParams 
}


 