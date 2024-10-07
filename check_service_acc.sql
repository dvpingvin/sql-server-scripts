USE [master]
GO

SELECT SERVERPROPERTY('SERVERNAME') AS [ServerName], SERVERPROPERTY('IsClustered') AS [IsClustered], SERVERPROPERTY('IsHADREnabled') AS [IsAlwaysOn], [servicename], [service_account],
CASE
WHEN ([servicename] LIKE 'SQL Server (%)' OR [servicename] LIKE 'SQL Server Agent (%)') AND [service_account] NOT LIKE '%\%$' AND (SERVERPROPERTY('IsClustered') = 1 OR SERVERPROPERTY('IsHADREnabled') = 1) THEN 'Поменяйте УЗ на gMSA'
WHEN [servicename] LIKE 'SQL Server (%)' AND ([service_account] NOT LIKE 'NT SERVICE\%$' OR [service_account] NOT LIKE '%\%$') AND SERVERPROPERTY('IsClustered') = 0 AND SERVERPROPERTY('IsHADREnabled') = 0 AND SERVERPROPERTY ('InstanceName') IS NULL THEN'Поменяйте УЗ на NT SERVICE\MSSQLSERVER'
WHEN [servicename] LIKE 'SQL Server Agent (%)' AND ([service_account] NOT LIKE 'NT SERVICE\%$' OR [service_account] NOT LIKE '%\%$') AND SERVERPROPERTY('IsClustered') = 0 AND SERVERPROPERTY('IsHADREnabled') = 0 AND SERVERPROPERTY ('InstanceName') IS NULL THEN 'Поменяйте УЗ на NT Service\SQLSERVERAGENT'
WHEN [servicename] LIKE 'SQL Server (%)' AND ([service_account] NOT LIKE 'NT SERVICE\%$' OR [service_account] NOT LIKE '%\%$') AND SERVERPROPERTY('IsClustered') = 0 AND SERVERPROPERTY('IsHADREnabled') = 0 AND SERVERPROPERTY ('InstanceName') IS NOT NULL  THEN 'Поменяйте УЗ на NT SERVICE\MSSQL$PAYROLL' + CONVERT (NVARCHAR(128), SERVERPROPERTY ('InstanceName'))
WHEN [servicename] LIKE 'SQL Server Agent (%)' AND ([service_account] NOT LIKE 'NT SERVICE\%$' OR [service_account] NOT LIKE '%\%$') AND SERVERPROPERTY('IsClustered') = 0 AND SERVERPROPERTY('IsHADREnabled') = 0 AND SERVERPROPERTY ('InstanceName') IS NOT NULL  THEN 'Поменяйте УЗ на NT SERVICE\SQLAGENT$PAYROLL' + CONVERT (NVARCHAR(128), SERVERPROPERTY ('InstanceName'))
WHEN [servicename] LIKE 'SQL Full-text Filter Daemon Launcher (%)' AND [service_account] <> 'NT Service\MSSQLFDLauncher' THEN 'Рекомендуется использовать NT Service\MSSQLFDLauncher'
ELSE 'OK. Действий не требуется'
END AS [Action]
FROM sys.dm_server_services
