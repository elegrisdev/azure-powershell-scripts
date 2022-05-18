<#
.SYNOPSIS
  Azure Container Registry Cleanup

.DESCRIPTION
  Login to Azure Container Registry and clean all images in the repositories older than the the specified number of days

.NOTES
  Version:          1.0
  Purpose/Change:   Initial script development
  Requirements:     AzureCLI
  Purpose:          Automation (Can still be executed manually)
#>

[CmdletBinding()]
Param(
    # Define Service Prinicipal Name for Azure authentication
    [Parameter(Mandatory=$true)]
    [String] $ServicePrincipalId,
    
    # Define Service Prinicial key for Azure authentication
    [Parameter(Mandatory=$true)]
    [String] $ServicePrincipalPass,

    # Define Tenant ID for Azure authentication
    [Parameter (Mandatory=$true)]
    [String] $ServicePrincipalTenant,

    # Define Azure Subscription Name
    [Parameter (Mandatory=$false)]
    [String] $SubscriptionName,
 
    # Define ACR Name
    [Parameter (Mandatory=$true)]
    [String] $AzureRegistryName,
 
    # Gets no of days from user; images older than this will be removed
    [Parameter (Mandatory=$false)]
    [String] $NoOfDays = "180",

    # Gets no of images to keep from user; images older than this will be removed
    [Parameter (Mandatory=$false)]
    [String] $NoOfKeptImages,

    # Allow the user to see what the script would have done, without actually deleting anything
    [Parameter (Mandatory=$false)]
    [bool] $DryRun = $false
)

$ErrorActionPreference = "Stop"

Function Remove-Image {
    param(
    [Parameter(Mandatory=$true)]
    [string] $registryName,

    [Parameter(Mandatory=$true)]
    [string] $imageName,

    [Parameter(Mandatory=$false)]
    [bool] $dryRun=$false
    )

    if($dryRun){
        Write-Host "Would have deleted $imageName"
    }
    else {
        Write-Host "Proceeding to delete image: $imageName"
        az acr repository delete --name $registryName --image $imageName --yes
    }
}

Write-Host "Establishing authentication with Azure..."
az login --service-principal -u $ServicePrincipalId -p $ServicePrincipalPass --tenant $ServicePrincipalTenant

if ($SubscriptionName){
    Write-Host "Setting subscription to: $SubscriptionName"
    az account set --subscription $SubscriptionName
}

Write-Host "Checking registry: $AzureRegistryName"
$RepoList = az acr repository list --name $AzureRegistryName --output table
for($index=2; $index -lt $RepoList.length; $index++){
    $RepositoryName = $RepoList[$index]

    Write-Host "Checking for repository: $RepositoryName"
    $RepositoryTags = az acr repository show-tags --name $AzureRegistryName --repository $RepositoryName --orderby time_desc --output tsv

    # Delete by count if user specified a $NoOfKeptImages
    if ($NoOfKeptImages -gt 0){
        #since the list is ordered, delete the last X items
        foreach($tag in $RepositoryTags){
            if($RepositoryTags.IndexOf($tag) -ge $NoOfKeptImages){
                $ImageName = $RepositoryName + ":" + $tag
                Remove-Image -registryName $AzureRegistryName -imageName $ImageName -dryRun $DryRun
            }
        }
    }
    # Delete by the age of the label (assuming yyyyMMdd convention in the tag names)
    else {
        foreach($tag in $RepositoryTags){
            $RepositoryTagName = $tag.ToString().Split('_')        

            $RepositoryTagBuildDay = $RepositoryTagName[-1].ToString().Split('.')[0]
            if($RepositoryTagBuildDay -eq "latest"){
                Write-Host "Skipping image: $RepositoryName/latest"
                continue;
            }

            $RepositoryTagBuildDay = [datetime]::ParseExact($repositorytagbuildday,'yyyyMMdd', $null)
            $ImageName = $RepositoryName + ":" + $tag

            if($RepositoryTagBuildDay -lt $((Get-Date).AddDays(-$NoOfDays))){
                Remove-Image -registryName $AzureRegistryName -imageName $ImageName -dryRun $DryRun
            }        
            else{
                Write-Host "Skipping image: $ImageName"
            }
        }
    }
}

Write-Host "Logging out of Azure"
az logout

Write-Host "Script execution finished"