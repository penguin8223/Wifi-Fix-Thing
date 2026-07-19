
function Logo-instructions {
    Clear-Host
    Write-Host @"
██     ██ ██ ███████ ██       ███████ ██ ██   ██       ████████ ██   ██ ██ ███    ██  ██████  
██     ██ ██ ██      ██       ██      ██  ██ ██           ██    ██   ██ ██ ████   ██ ██       
██  █  ██ ██ █████   ██ █████ █████   ██   ███   █████    ██    ███████ ██ ██ ██  ██ ██   ███ 
██ ███ ██ ██ ██      ██       ██      ██  ██ ██           ██    ██   ██ ██ ██  ██ ██ ██    ██ 
 ███ ███  ██ ██      ██       ██      ██ ██   ██          ██    ██   ██ ██ ██   ████  ██████  

        Wifi-Fix-Thing v1.0                                                                                     
"@

    Write-Host ""
    Write-Host "This script is designed to troubleshoot WiFi issues for non-technical users :)"
    Write-Host ""
    Write-Host "===== Options Available ====="
    Write-Host "1. Restart Wifi Antenna"
    Write-Host "2. Restart Computer Internet"
    Write-Host "3. Clear Domain Name Server (DNS) Cache"
    Write-Host "4. Get Wifi Antenna Status"
    Write-Host "5. Reboot Computer"
    Write-Host "6. Help"
    Write-Host "7. Exit"
    Write-Host ""



}

function Get-interfaces-status {
    $adapters = Get-NetAdapter | Sort-Object -Property ifIndex

    #If no interfaces are found notify the user
    if (-not $adapters) {
        Write-Host "No network adapter found." -ForegroundColor red 
        Write-Host ""
        Read-Host "Press Enter to return to the menu..."
        return
    }

    #Output the status of each interface
    foreach ($adapter in $adapters) {

        #Color code based on status
        switch ($adapter.Status) {
            'Up'            { $statusColor = 'Green' }
            'Disconnected'  { $statusColor = 'Yellow' }
            'Disabled'      { $statusColor = 'DarkGray' }
            default         { $statusColor = 'Red' }
        }
    Write-Host ""
    Write-Host "[$($adapter.Name)]" -NoNewline -ForegroundColor White
    Write-Host "$($adapter.Status)" -ForegroundColor $statusColor
    Write-Host " Description : $($adapter.InterfaceDescription)"
    Write-Host " Link Speed : $($adapter.LinkSpeed)"

    #Pull info of online interfaces
    if ($adapter.Status -eq 'Up') {
        $ipConfig = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue

        if ($ipConfig) {
            foreach ($ip in $ipConfig) {
                Write-Host " IP Address: $($ip.IPAddress)/$($ip.PrefixLength)"

            }
        } 
        } else {
            Write-Host " IP Address : none assigned" -ForegroundColor Yellow
        }

    #Get DNS info of online interfaces
     $DnsServer = Get-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
    
    if ($DnsServer -and $DnsServer.ServerAddresses.Count -gt 0) {
        $dnsList = $DnsServer.ServerAddresses -join ", "
        Write-Host " DNS Server : $dnsList"
    } else {
        Write-Host " DNS Server : none configured" -ForegroundColor Yellow
    }
    }  
    
    Write-Host ""
    Read-Host "Press Enter to return to the menu..."
}

function FlushDNSChache {
    Write-Host ""
    Write-Host "======== Flushing DNS Chache ========" -ForegroundColor Cyan

    try {
        Clear-DnsClientCache -ErrorAction Stop 
        Write-Host "DNS chache has been flushed successfully"
    } catch {
        Write-Host "Clear-DnsClientChache failed: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "Falling back to ipconfig /flushdns..." -ForegroundColor Yellow

        $result = ipconfig /flushdns
        Write-Host $result

        if ($result -match "Successfully flused") {
            Write-Host "DNS cache flushed via ipconfig successfully." -ForegroundColor Green
        } else {
            Write-Host "Could not confirm the cache was flushed. Try running this script as Administrator." -ForegroundColor Red
        }
    }
Write-Host ""
Read-Host "Press Enter to return to the menu..."

}

function Restart-NetworkServices {
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "This funciton requires Administrator rights. Re-run this script as Administrator." -ForegroundColor Red
        return
    }

    $services = @(
        @{ Name = "Dhcp";   Label = "DHCP Client"},
        @{ Name = "Dnscache";   Label = "DNS Client"},
        @{ Name = "Netman";   Label = "Network Connections"},
        @{ Name = "NlaSvc";   Label = "Network Location Awareness"},
        @{ Name = "netprofm";   Label = "Network List Service"}
    )

    Write-Host ""
    Write-Host "=== Restarting Core Network Services ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "***NOTE: This will briefly interrupt internet connection***"

    foreach ($svc in $services) {
        try {
            $serviceObj = Get-Service -Name $svc.Name -ErrorAction Stop

            if ($serviceObj.Status -eq 'Running') {
                Write-Host "Restarting $($svc.Label) | ($($svc.Name))..." -NoNewline
                Restart-Service -Name $svc.Name -Force -ErrorAction Stop
                Write-Host " Done." -ForegroundColor Green
            } else {
                Write-Host "Starting $($svc.Label) | ($($svc.Name))..." -NoNewline
                Start-Service -Name $svc.Name -ErrorAction Stop
                Write-Host " Done." -ForegroundColor Green
            }
        } catch {
            Write-Host " FAILED: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    Write-Host ""
    Write-Host "Core network services have restarted. Give it a few seconds, then re-check connectivity." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press Enter to return to menu..." 
    
}

function Restart-WlanAdapter {
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "This option requires Administration priviliges. Re-run this script as Administrator." -ForegroundColor Red
        return
    } 

    Write-Host ""
    Write-Host "=== Restarting Wireless Adapter ===" -ForegroundColor Cyan

    #Priamry method by matching physical media type
    $WlanAdapters = Get-NetAdapter | Where-Object { $_.PhysicalMediaType -eq "Native 802.11" }

    #Fallback method by matching description
    if (-not $WlanAdapters) {
        Write-Host "No wireless adapters were found. Atempting fallback method" -ForegroundColor Yellow
        $WlanAdapters = Get-NetAdapter | Where-Object {
            $_.InterfaceDescription -match "Wireless|WiFi|Wi-Fi|WLAN|802.11"
        }
    }

    if (-not $WlanAdapters) {
        Write-Host ""
        Write-Host "No wireless adapter could be identified." -ForegroundColor Red
        Write-Host "Try Manually seraching for the wireless adapter" -ForegroundColor Yellow
        return
    }

    foreach ($adapter in $WlanAdapters) {
        Write-Host ""
        Write-Host "Found wireless adapter: $($adapter.Name) ($($adapter.InterfaceDescription))" -ForegroundColor White
        Write-Host "Current status: $($adapter.Status)"

        $confirm_restart = Read-Host "Restart this adapter? (Y/N)"
        if ($confirm_restart -notmatch '^[Yy]') {
            Write-Host "Will not restart adapter: $($adapter.Name)." -ForegroundColor Yellow
            continue
        }

        try {
            Write-Host "Stopping $($adapter.Name)..." -NoNewline
            Disable-NetAdapter -Name $adapter.Name -Confirm:$false -ErrorAction Stop
            Write-Host " Done." -ForegroundColor Green

            Start-Sleep -Seconds 3

            Write-Host "Starting $($adapter.Name)..." -NoNewline
            Enable-NetAdapter -Name $adapter.Name -Confirm:$false -ErrorAction Stop
            Write-Host " Done." -ForegroundColor Green

            Start-Sleep -Seconds 2
            $updated = Get-NetAdapter -Name $adapter.Name
            Write-Host "New Status: $($updated.Status)" -ForegroundColor Cyan
        } catch {
            Write-Host " FAILED: $($_.Exception.Message)" -ForegroundColor Red
        }

    Write-Host ""
    }
}

function Reboot-Computer {
    Write-Host ""
    Write-Host "=== Restart Computer ===" -ForegroundColor Cyan
    Write-Host "***Before you restart save any work on your computer***"

    $confirm_reboot = Read-Host "Would you like to restart the computer? (Y/N)"

    if ($confirm_reboot -notmatch '^[Yy]') {
        Write-Host "Will not restart the computer." -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "Restarting Computer this may take a moment..." -ForegroundColor Yellow

    shutdown /r /f /t 5

}

function Show-Help {
    $readmePath = Join-Path $PSScriptRoot "README.md"

    if (Test-Path $readmePath) {
        #Open the Readme file
        Invoke-Item $readmePath
    } else {
        Write-Host "README.md not found, please open it manually in the script folder."
    }
}
function Exit-Script {
    Write-Host "Exiting Script..."
    exit
}

#Run the script as a While True loop
do {
    #Run Logo funciton
    Logo-instructions

    #Input user choice
    $Main_menu_input = Read-Host "Select an option [1-7]: "

    #Ask user for main menu options
    switch ($Main_menu_input) { 
        "1" { Restart-WlanAdapter}
        "2" { Restart-NetworkServices }
        "3" { FlushDNSChache }
        "4" { Get-interfaces-status }
        "5" { Reboot-Computer }
        "6" { Show-Help }
        "7" { Exit-Script }
        default { 
            Write-Host "Option not found, please select an option form the menu [1-7]." -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }
} while ($true)