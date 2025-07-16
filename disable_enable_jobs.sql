USE [msdb]
GO
SELECT
'msdb.dbo.sp_update_job @job_name=N''' + name + ''', @enabled=0' AS [disable],
'msdb.dbo.sp_update_job @job_name=N''' + name + ''', @enabled=1' AS [enable]
FROM msdb..sysjobs
WHERE enabled = 1
