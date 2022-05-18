<#
.SYNOPSIS
  Audit Azure AD service principals to get expired, near to expire and recent logins of Service Principals

.DESCRIPTION
  Login with AzureAD module
  Get expired and near to expire certificates and secrets, then export to CSV
  Get SignIns count per application and export to CSV

.NOTES
  Version:          1.0
  Purpose/Change:   Initial script development
  Requirements:     PowerShell 5, AzureAD Module, MSAL.PS module
  Purpose:          Automation (Can still be executed manually)
#>

[CmdletBinding()]
Param (
    [Parameter(Mandatory = $true)]
    [string] $tenantId,

    [Parameter(Mandatory = $true)]
    [string] $applicationId,

    [Parameter(Mandatory = $true)]
    [string] $thumbprint,

    [Parameter(Mandatory = $false)]
    [int] $expireDays = 60,

    [Parameter(Mandatory = $false)]
    [bool] $listAlreadyExpired = $true,

    [Parameter(Mandatory = $false)]
    [string] $expiredPath = "C:\temp\expired.csv",

    [Parameter(Mandatory = $false)]
    [string] $auditPath = "C:\temp\audit.csv"
)

$ErrorActionPreference = 'Stop'

function ExpiredApplications () {

    # Azure Authentication

    Connect-AzureAD -TenantId $tenantId -ApplicationId $applicationId -CertificateThumbprint $thumbprint

    $Applications = Get-AzureADApplication -all $true
    $Logs = @()
    $Days = $expireDays
    $AlreadyExpired = $listAlreadyExpired

    $now = get-date

    foreach ($app in $Applications) {
        $AppName = $app.DisplayName
        $AppID = $app.objectid
        $ApplID = $app.AppId
        $AppCreds = Get-AzureADApplication -ObjectId $AppID | Select-Object PasswordCredentials, KeyCredentials
        $secret = $AppCreds.PasswordCredentials
        $cert = $AppCreds.KeyCredentials

        foreach ($s in $secret) {
            $StartDate = $s.StartDate
            $EndDate = $s.EndDate
            $KeyId = $s.KeyId
            $operation = $EndDate - $now
            $ODays = $operation.Days

            if ($AlreadyExpired -eq $false) {
                if ($ODays -le $Days -and $ODays -ge 0) {

                    $Owner = Get-AzureADApplicationOwner -ObjectId $app.ObjectId
                    $Username = $Owner.UserPrincipalName -join ";"
                    $OwnerID = $Owner.ObjectID -join ";"
                    if ($Null -eq $owner.UserPrincipalName) {
                        $Username = $Owner.DisplayName + " **<This is an Application>**"
                    }
                    if ($null -eq $Owner.DisplayName) {
                        $Username = "<<No Owner>>"
                    }

                    $Log = New-Object System.Object

                    $Log | Add-Member -MemberType NoteProperty -Name "ApplicationName" -Value $AppName
                    $Log | Add-Member -MemberType NoteProperty -Name "ApplicationID" -Value $ApplID
                    $Log | Add-Member -MemberType NoteProperty -Name "Key ID" -Value $KeyId
                    $Log | Add-Member -MemberType NoteProperty -Name "Secret Start Date" -Value $StartDate
                    $Log | Add-Member -MemberType NoteProperty -Name "Secret End Date" -value $EndDate
                    $Log | Add-Member -MemberType NoteProperty -Name "Certificate Start Date" -Value $Null
                    $Log | Add-Member -MemberType NoteProperty -Name "Certificate End Date" -value $Null
                    $Log | Add-Member -MemberType NoteProperty -Name "Owner" -Value $Username
                    $Log | Add-Member -MemberType NoteProperty -Name "Owner_ObjectID" -value $OwnerID

                    $Logs += $Log
                }
            }
            elseif ($AlreadyExpired) {
                if ($ODays -le $Days) {
                    $Owner = Get-AzureADApplicationOwner -ObjectId $app.ObjectId
                    $Username = $Owner.UserPrincipalName -join ";"
                    $OwnerID = $Owner.ObjectID -join ";"
                    if ($Null -eq $owner.UserPrincipalName) {
                        $Username = $Owner.DisplayName + " **<This is an Application>**"
                    }
                    if ($null -eq $Owner.DisplayName) {
                        $Username = "<<No Owner>>"
                    }

                    $Log = New-Object System.Object
        
                    $Log | Add-Member -MemberType NoteProperty -Name "ApplicationName" -Value $AppName
                    $Log | Add-Member -MemberType NoteProperty -Name "ApplicationID" -Value $ApplID
                    $Log | Add-Member -MemberType NoteProperty -Name "Key ID" -Value $KeyId
                    $Log | Add-Member -MemberType NoteProperty -Name "Secret Start Date" -Value $StartDate
                    $Log | Add-Member -MemberType NoteProperty -Name "Secret End Date" -value $EndDate
                    $Log | Add-Member -MemberType NoteProperty -Name "Certificate Start Date" -Value $Null
                    $Log | Add-Member -MemberType NoteProperty -Name "Certificate End Date" -value $Null
                    $Log | Add-Member -MemberType NoteProperty -Name "Owner" -Value $Username
                    $Log | Add-Member -MemberType NoteProperty -Name "Owner_ObjectID" -value $OwnerID

                    $Logs += $Log
                }
            }
        }

        foreach ($c in $cert) {
            $CStartDate = $c.StartDate
            $CEndDate = $c.EndDate
            $KeyId = $c.KeyId
            $COperation = $CEndDate - $now
            $CODays = $COperation.Days

            if ($AlreadyExpired -eq $false) {
                if ($CODays -le $Days -and $CODays -ge 0) {

                    $Owner = Get-AzureADApplicationOwner -ObjectId $app.ObjectId
                    $Username = $Owner.UserPrincipalName -join ";"
                    $OwnerID = $Owner.ObjectID -join ";"
                    if ($Null -eq $owner.UserPrincipalName) {
                        $Username = $Owner.DisplayName + " **<This is an Application>**"
                    }
                    if ($null -eq $Owner.DisplayName) {
                        $Username = "<<No Owner>>"
                    }

                    $Log = New-Object System.Object

                    $Log | Add-Member -MemberType NoteProperty -Name "ApplicationName" -Value $AppName
                    $Log | Add-Member -MemberType NoteProperty -Name "ApplicationID" -Value $ApplID
                    $Log | Add-Member -MemberType NoteProperty -Name "Key ID" -Value $KeyId
                    $Log | Add-Member -MemberType NoteProperty -Name "Certificate Start Date" -Value $CStartDate
                    $Log | Add-Member -MemberType NoteProperty -Name "Certificate End Date" -value $CEndDate
                    $Log | Add-Member -MemberType NoteProperty -Name "Owner" -Value $Username
                    $Log | Add-Member -MemberType NoteProperty -Name "Owner_ObjectID" -value $OwnerID

                    $Logs += $Log
                }
            }
            elseif ($AlreadyExpired) {
                if ($CODays -le $Days) {

                    $Owner = Get-AzureADApplicationOwner -ObjectId $app.ObjectId
                    $Username = $Owner.UserPrincipalName -join ";"
                    $OwnerID = $Owner.ObjectID -join ";"
                    if ($Null -eq $owner.UserPrincipalName) {
                        $Username = $Owner.DisplayName + " **<This is an Application>**"
                    }
                    if ($null -eq $Owner.DisplayName) {
                        $Username = "<<No Owner>>"
                    }

                    $Log = New-Object System.Object

                    $Log | Add-Member -MemberType NoteProperty -Name "ApplicationName" -Value $AppName
                    $Log | Add-Member -MemberType NoteProperty -Name "ApplicationID" -Value $ApplID
                    $Log | Add-Member -MemberType NoteProperty -Name "Key ID" -Value $KeyId
                    $Log | Add-Member -MemberType NoteProperty -Name "Certificate Start Date" -Value $CStartDate
                    $Log | Add-Member -MemberType NoteProperty -Name "Certificate End Date" -value $CEndDate
                    $Log | Add-Member -MemberType NoteProperty -Name "Owner" -Value $Username
                    $Log | Add-Member -MemberType NoteProperty -Name "Owner_ObjectID" -value $OwnerID

                    $Logs += $Log
                }
            }
        }
    }

    $Logs | Export-CSV $expiredPath -NoTypeInformation -Encoding UTF8
}

function SignInsAudit () {
    
    # Get Azure Authentication Token

    $ClientCertificate = Get-Item "Cert:\LocalMachine\My\$($thumbPrint)"

    $accessToken = Get-MsalToken -TenantId $tenantId -ClientId $applicationId -ClientCertificate $ClientCertificate | Select-Object -Property AccessToken

    # MS Graph Apps URI

    $aadAppsURI = 'https://graph.microsoft.com/v1.0/applications'

    # MS Graph Directory Audit URI

    $signInsURI = 'https://graph.microsoft.com/v1.0/auditLogs/directoryAudits'

    # Report Template

    $aadAppReportTemplate = [pscustomobject][ordered]@{
        displayName     = $null
        createdDateTime = $null
        signInAudience  = $null
    }

    # Get Apps

    $aadApplications = @()
    $Logs = @()

    $aadApps = Invoke-RestMethod -Headers @{Authorization = "Bearer $($accessToken.AccessToken)" } -Uri  $aadAppsURI -Method Get

    if ($aadApps.value) {

        $aadApplications += $aadApps.value

        # More Apps?

        if ($aadApps.'@odata.nextLink') {

            $nextPageURI = $aadApps.'@odata.nextLink'

            do {

                $aadApps = $null

                $aadApps = Invoke-RestMethod -Headers @{Authorization = "Bearer $($accessToken.AccessToken)" } -Uri  $nextPageURI -Method Get

                if ($aadApps.value) {

                    $aadApplications += $aadApps.value

                    $aadApplications.value.Count

                }

                if ($aadApps.'@odata.nextLink') {

                    $nextPageURI = $aadApps.'@odata.nextLink'

                }

                else {

                    $nextPageURI = $null

                }

            } until (!$nextPageURI)

        }

    }

    $aadApplications = $aadApplications | Sort-Object -Property createdDateTime -Descending

    foreach ($app in $aadApplications) {

        # Report Output

        $reportData = $aadAppReportTemplate.PsObject.Copy()
        $reportData.displayName = $app.displayName
        $reportData.createdDateTime = $app.createdDateTime
        $reportData.signInAudience = $app.signInAudience

        # SignIns

        $appSignIns = $null

        $appSignIns = Invoke-RestMethod -Headers @{Authorization = "Bearer $($accessToken.AccessToken)" } -Uri "$($signInsURI)?&`$filter=targetResources/any(t: t/id eq `'$($app.id)`')" -Method Get

        if ($appSignIns.value) {

            $Log = New-Object System.Object

            $Log | Add-Member -MemberType NoteProperty -Name "ApplicationName" -Value $app.DisplayName
            $Log | Add-Member -MemberType NoteProperty -Name "AppId" -Value $app.AppId
            $Log | Add-Member -MemberType NoteProperty -Name "RecentSignIns" -Value $appSignIns.value.count

            $Logs += $Log

        }

        else {

            $Log = New-Object System.Object

            $Log | Add-Member -MemberType NoteProperty -Name "ApplicationName" -Value $app.DisplayName
            $Log | Add-Member -MemberType NoteProperty -Name "AppId" -Value $app.AppId
            $Log | Add-Member -MemberType NoteProperty -Name "RecentSignIns" -Value $appSignIns.value.count

            $Logs += $Log

        }
    }

    $Logs | Export-CSV $auditPath -NoTypeInformation -Encoding UTF8
}

ExpiredApplications
SignInsAudit


