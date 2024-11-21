# В файл C:\Temp\Servers.txt вставляете список серверов в столбик
$servers = Get-Content "C:\Temp\Servers.txt"

# указываете ТУЗ для которой необходимо сменить пароль без указания домена
$tuz = "CAB-SA-SQL00034"
$Credential = Get-Credential

#Далее выполняем последовательно пункты скрипта

# 1.
#===========================
#Останавливаете сервисы со статусом, отличном от Stopped
foreach($server in $servers)
    {
    (Get-WmiObject -ClassName Win32_Service -ComputerName $server | where {$_.StartName -match $tuz -and $_.Status -notmatch 'Stopped'}).StopService()
    }
#===========================

# 2.
#===========================
#Меняете имя и пароль для запуска сервиса
foreach($server in $servers)
    {
    (Get-WmiObject -ClassName Win32_Service -ComputerName $server | where {$_.StartName -match $tuz}).Change($null,$null,$null,$null,$null,$null,$credential.UserName,$credential.GetNetworkCredential().Password,$null,$null,$null)
    }
#===========================

# 3. 
#===========================
#Запускаете сервис со статусом, отличном от Running
foreach($server in $servers)
    {
    (Get-WmiObject -ClassName Win32_Service -ComputerName $server | where {$_.StartName -match $tuz -and $_.Status -notmatch 'Running'}).StartService()
    }
#===========================

# 4.
#===========================
#Показывает статус сервиса, отличного от Running
foreach($server in $servers)
    {
    Get-WmiObject -ClassName Win32_Service -ComputerName $server | where {$_.StartName -match $tuz -and $_.State -notmatch 'Running'} | select PSComputerName,Name,StartName,State
    }
#===========================
