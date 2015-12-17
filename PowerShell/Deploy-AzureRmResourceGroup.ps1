#Requires -Version 3.0
#Requires -Module AzureRM.Resources
#Requires -Module Azure.Storage

Param (
    [string] [Parameter(Mandatory=$true)] $TemplateFile,
    [string] [Parameter(Mandatory=$true)] $Location,
    [string] $TemplateParameterFile,
    [string] $ResourceGroupName
)

Set-StrictMode -Version 3

Import-Module Azure -ErrorAction SilentlyContinue

try {
    [Microsoft.Azure.Common.Authentication.AzureSession]::ClientFactory.AddUserAgent("XPlat_PS_Script-$UI$($host.name)".replace(" ","_"), "1.0")
} catch { }

$artifactsParameters = New-Object -TypeName Hashtable
$templateName = (Get-ChildItem -Path $TemplateFile).BaseName
$templateDirectory = (Get-Item -Path (split-path $TemplateFile)).FullName
$artifactsSourceFolder = Join-Path -Path $templateDirectory -ChildPath 'Artifacts'
$dscSourceFolder = Join-Path -Path $templateDirectory -ChildPath 'DSC'

if ([string]::IsNullOrEmpty($TemplateParameterFile)) {
    $TemplateParameterFile = "$templateDirectory\$templateName.parameters.json"
}

if ([string]::IsNullOrEmpty($ResourceGroupName)) {
    $ResourceGroupName = $templateName;
}

# When $dscSourceFolder contains files, they will be zipped into a file under $artifactsSourceFolder\DSCModules.
if ((Get-ChildItem -Path $dscSourceFolder -Recurse -Attributes !D).length -gt 0) {
    $dscModuleFolder = Join-Path -Path $artifactsSourceFolder -ChildPath 'DSCModules'
    New-Item -Path $dscModuleFolder -ItemType directory -Force | Out-Null
    $dscModuleFile = Join-Path -Path $dscModuleFolder -ChildPath 'dsc.zip'
    Remove-Item -Path $dscModuleFile -ErrorAction SilentlyContinue
    Add-Type -Assembly System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory($dscSourceFolder, $dscModuleFile)
}

# When $artifactsSourceFolder contains files, they will be staged in a storage account.
$artifactFilePaths = Get-ChildItem -Path $artifactsSourceFolder -Recurse -Attributes !D | ForEach-Object -Process {$_.FullName}
if (($artifactFilePaths | Measure-Object -Line).Lines -gt 0) {
    $subscriptionId = (Get-AzureRmContext).Subscription.SubscriptionId
    $artifactsResourceGroupName = 'ARM_Deploy_Staging'
    $artifactsStorageAccountName = "armstaging$($subscriptionId.substring(0, 8))"
    $artifactsStorageContainerName = "$ResourceGroupName-stageartifacts".ToLower()

    New-AzureRmResourceGroup -Location "$Location" -Name $artifactsResourceGroupName -Force
    New-AzureRmStorageAccount -StorageAccountName $artifactsStorageAccountName -Type 'Standard_LRS' -ResourceGroupName $artifactsResourceGroupName -Location "$Location"
    $artifactsStorageAccountKey = (Get-AzureRmStorageAccountKey -ResourceGroupName $artifactsResourceGroupName -Name $artifactsStorageAccountName).Key1
    $artifactsStorageAccountContext = New-AzureStorageContext -StorageAccountName $artifactsStorageAccountName -StorageAccountKey $artifactsStorageAccountKey
    New-AzureStorageContainer -Name $artifactsStorageContainerName -Permission Off -Context $artifactsStorageAccountContext -ErrorAction SilentlyContinue
    $artifactsLocationSasToken = New-AzureStorageContainerSASToken -Container $artifactsStorageContainerName -Context $artifactsStorageAccountContext -Permission r -ExpiryTime (Get-Date).ToUniversalTime().AddHours(4)
    $artifactsLocationSasToken = ConvertTo-SecureString $artifactsLocationSasToken -AsPlainText -Force

    $artifactsParameters.Add('_artifactsLocation', $artifactsStorageAccountContext.BlobEndPoint + $artifactsStorageContainerName)
    $artifactsParameters.Add('_artifactsLocationSasToken', $artifactsLocationSasToken)

    Write-Host $artifactFilePaths
    foreach ($sourcePath in $artifactFilePaths) {
        $blobName = $sourcePath.Substring($artifactsSourceFolder.length + 1).Replace('\', '/')
        Set-AzureStorageBlobContent -File $sourcePath -Blob $blobName -Container $artifactsStorageContainerName -Context $artifactsStorageAccountContext -Force
    }
}

# Create or update the resource group using the specified template file and template parameters file
New-AzureRMResourceGroup -Name $ResourceGroupName -Location "$Location" -Verbose -Force -ErrorAction Stop
New-AzureRmResourceGroupDeployment -Name 'XPlat_PS_Script' `
                                   -ResourceGroupName $ResourceGroupName `
                                   -TemplateFile $TemplateFile `
                                   -TemplateParameterFile $TemplateParameterFile `
                                   @artifactsParameters `
                                   -Force -Verbose