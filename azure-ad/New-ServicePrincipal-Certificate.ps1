<#
.SYNOPSIS
  Create a new service principal with a self signed certificate with read permissions on applications and audits in Azure AD
  Update an existing application with a new certificate

.DESCRIPTION
  Login with AzureAD to create the application
  Login with AzureCLI to give API permissions and administrator consent

.NOTES
  Version:          1.0
  Purpose/Change:   Initial script development
  Requirements:     PowerShell 5, AzureAD Module, AzureCLI
  Purpose:          Manually by an administrator
#>

[CmdletBinding()]
Param(
    # Prefix of the tenant URI
    [Parameter(Mandatory = $true)]
    [string] $tenantPrefix,

    # Full path of the generated certificate
    [Parameter(Mandatory = $false)]
    [string] $certPath = "C:\temp\mycert.pfx",

    # Disaply name for the Azure AD application
    [Parameter(Mandatory = $true)]
    [string] $appMonitoringName,

    [Parameter(Mandatory = $true)]
    [securestring] $certPassword
)

$ErrorActionPreference = 'Stop'

function GenerateCertificate () {
    # Create a self signed certificate

    $password = $certPassword
    $notAfter = ((Get-Date).AddMonths(6)).toString("yyyy-MM-dd")
    $thumb = (New-SelfSignedCertificate -DnsName "${tenantPrefix}.onmicrosoft.com" -CertStoreLocation "cert:\LocalMachine\My"  -KeyExportPolicy Exportable -Provider "Microsoft Enhanced RSA and AES Cryptographic Provider" -NotAfter $notAfter).Thumbprint
    Export-PfxCertificate -cert "cert:\localmachine\my\$thumb" -FilePath $certPath -Password $password

    # Load the certificate

    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate("${certPath}", $password)
    $keyValue = [System.Convert]::ToBase64String($cert.GetRawCertData())

    return $keyValue, $notAfter
}

function CreateNewApp () {

    # Create the Azure Active Directory Application

    $returnedData = GenerateCertificate
    $keyValue = $returnedData[1]
    $notAfter = $returnedData[2]
    $application = New-AzureADApplication -DisplayName $appMonitoringName
    New-AzureADApplicationKeyCredential -ObjectId $application.ObjectId -CustomKeyIdentifier $appMonitoringName -Type AsymmetricX509Cert -Usage Verify -Value $keyValue -EndDate $notAfter

    # Create the Service Principal and connect it to the Application

    $sp=New-AzureADServicePrincipal -AppId $application.AppId

    # Give the Service Principal Reader access to the current tenant (Get-AzureADDirectoryRole)

    Add-AzureADDirectoryRoleMember -ObjectId (Get-AzureADDirectoryRole | where-object {$_.DisplayName -eq "Directory Readers"}).Objectid -RefObjectId $sp.ObjectId

    # Connect to Azure Login

    az login

    Write-Host "Entering sleep mode for 30 seconds before creating permissions, please wait..." -ForegroundColor Green
    Start-Sleep -s 30

    $Permissions= @("df021288-bdef-4463-88db-98f22de89214", "b0afded3-3588-46d8-8b3d-9842eff778da")

    foreach ( $Permission in $Permissions ) {
        az ad app permission add --api "00000003-0000-0000-c000-000000000000" --api-permissions "${Permission}=Role" --id $application.AppId
    }

    az ad app permission grant --id $application.AppId --api "00000003-0000-0000-c000-000000000000"

    Write-Host "Entering sleep mode for 30 seconds before admin consent, please wait..." -ForegroundColor Green
    Start-Sleep -s 30

    az ad app permission admin-consent --id $application.AppId
}

function UpdateCurrentApp () {

    $returnedData = GenerateCertificate
    $keyValue = $returnedData[1]
    $notAfter = $returnedData[2]
    $application = Get-AzureADApplication -Filter "DisplayName eq '${appMonitoringName}'"
    New-AzureADApplicationKeyCredential -ObjectId $application.ObjectId -CustomKeyIdentifier $appMonitoringName -Type AsymmetricX509Cert -Usage Verify -Value $keyValue -EndDate $notAfter
}


Connect-AzureAD

$CheckExistingSP= (Get-AzureADApplication -Filter "DisplayName eq '${appMonitoringName}'")

if ( $CheckExistingSP ) {
    $answer = $(Write-Host "The name of the application already exist. Do you want to update the existing application with a new certificate ? (y/n)" -ForegroundColor Yellow ; Read-Host)
    if ( $answer -eq 'y' ) {
        Write-Host "Updating current application..." -ForegroundColor Green
        UpdateCurrentApp
    }
    else {
        Write-Host "Exiting..."
        break
    }
    
}
else {
    Write-Host "Creating new application..." -ForegroundColor Green
    CreateNewApp
}