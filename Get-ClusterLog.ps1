$minutes = [int]((Get-Date) - (Get-Date "2026-02-19 19:10")).TotalMinutes + 30
Get-ClusterLog -TimeSpan $minutes -Destination C:\Temp -UseLocalTime
 
$startTime = "2026/02/19-19:00"
$endTime = "2026/02/19-19:15"
 
Get-ChildItem C:\Temp\*_cluster.log | ForEach-Object {
    $outFile = "C:\Temp\filtered_$($_.Name)"
    Get-Content $_.FullName -Encoding Unicode | Where-Object {
        if ($_ -match "::(\d{4}/\d{2}/\d{2}-\d{2}:\d{2}:\d{2})") {
            $matches[1] -ge $startTime -and $matches[1] -le $endTime
        } else {
            $false
        }
    } | Out-File $outFile -Encoding Unicode
    Write-Host "Created: $outFile"
}

Get-Content -Path "C:\Temp\CAB-PSP-QUIK018_cluster.log" | Where-Object { $_ -match "\[RES\] SQL Server <SQL Server>: \[sqsrvres\] " } | Set-Content -Path "C:\Temp\SQL_Server_Errors_CAB-PSP-QUIK017.log"
Get-Content -Path "C:\Temp\CAB-PSP-QUIK018_cluster.log" | Where-Object { $_ -match "\[RES\] SQL Server <SQL Server>: \[sqsrvres\] " } | Set-Content -Path "C:\Temp\SQL_Server_Errors_CAB-PSP-QUIK018.log"
