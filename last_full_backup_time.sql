SELECT database_name, MAX(backup_start_date) AS [last_backup_start_date], MAX(backup_finish_date) AS [last_backup_finish_date]
FROM msdb.dbo.backupset
GROUP BY database_name
WHERE type = 'D'
