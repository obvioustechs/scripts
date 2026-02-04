$graphConfig = Get-Content "C:\scripts\config\graph.json" | ConvertFrom-Json
$connect = @{
    ClientId = $graphConfig.ClientId
    TenantId = $graphConfig.TenantId
    CertificateThumbprint = $graphConfig.CertificateThumbprint
    NoWelcome = $true
}

Connect-MgGraph @connect

$users = Get-MgUser -Filter 'accountEnabled eq true' -All

$mfaConfig = Get-Content "C:\scripts\config\user_mfa_status.json" | ConvertFrom-Json
$skipUsers = $mfaConfig.skipUsers

$validMethods = @(
    "#microsoft.graph.emailAuthenticationMethod"
    "#microsoft.graph.fido2AuthenticationMethod"
    "#microsoft.graph.microsoftAuthenticatorAuthenticationMethod"
    "#microsoft.graph.softwareOathAuthenticationMethod"
    "#microsoft.graph.windowsHelloForBusinessAuthenticationMethod"
)

$usersWithoutMFA = @()

foreach ($user in $users) {
    if ($skipUsers.Contains($user.UserPrincipalName)) {
        continue
    }

    $methods = Get-MgUserAuthenticationMethod -UserId $user.UserPrincipalName
    $mfa = $false

    foreach ($method in $methods) {
        if ($validMethods.Contains($method.AdditionalProperties["@odata.type"])) {
            $mfa = $true
            break
        }
    }

    if (!$mfa) {
        $usersWithoutMFA += $user
    }
}

if ($usersWithoutMFA.Count -gt 0) {
    $emailConfig = Get-Content "C:\scripts\config\email.json" | ConvertFrom-Json
    $body = "Please review these users and get them registered for MFA.`r`n`r`n"

    foreach ($user in $usersWithoutMFA) {
        $body += "$($user.DisplayName) ($($user.UserPrincipalName))`r`n"
    }

    $message = @{
        subject = "Enabled Users Missing MFA Registration"
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
