$graphConfig = Get-Content "C:\scripts\config\graph.json" | ConvertFrom-Json
$connect = @{
    ClientId = $graphConfig.ClientId
    TenantId = $graphConfig.TenantId
    CertificateThumbprint = $graphConfig.CertificateThumbprint
    NoWelcome = $true
}

$users = Get-AdUser -Filter 'PasswordNeverExpires -eq $false -and Enabled -eq $true' -Properties Name, SamAccountName, Enabled, PasswordNeverExpires, PwdLastSet

$passwordConfig = Get-Content "C:\scripts\config\user_password_expiration.json" | ConvertFrom-Json
$skipUsers = $passwordConfig.skipUsers

$unsetPasswordUsers = @()
$passwordExpiresUsers = @()

foreach ($user in $users) {
    if ($skipUsers.Contains($user.SamAccountName)) {
        continue
    }

    if ($user.PwdLastSet -eq 0) {
        $unsetPasswordUsers += $user
    } else {
        $passwordExpiresUsers += $user
    }
}

foreach ($user in $passwordExpiresUsers) {
    Set-AdUser -Identity $user.SamAccountName -PasswordNeverExpires $true
}

if ($passwordExpiresUsers.Count -gt 0) {
    Connect-MgGraph @connect

    $emailConfig = Get-Content "C:\scripts\config\email.json" | ConvertFrom-Json
    $body = "The following users had passwords set to expire, now corrected.`r`n`r`n"

    foreach ($user in $passwordExpiresUsers) {
        $body += "$($user.Name)`r`n"
    }

    if ($unsetPasswordUsers.Count -gt 0) {
        $body += "`r`nThe users below have not yet set their initial password. No changes made.`r`n`r`n"

        foreach ($user in $unsetPasswordUsers) {
            $body += "$($user.Name)`r`n"
        }
    }

    $message = @{
        subject = "Enabled Users Password Set to Expire"
        body = @{
            contentType = "text"
            content = $body
        }
        toRecipients = @(
            @{
                emailAddress = @{
                    address = $emailConfig.to
                }
            }
        )
    }

    Send-MgUserMail -UserId $emailConfig.from -Message $message
}
