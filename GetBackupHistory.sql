-- Get Backup History for required database
SELECT TOP 100
s.server_name,
s.database_name,
s.recovery_model,
m.physical_device_name,
CAST(CAST(s.backup_size / 1000000 AS INT) AS VARCHAR(14)) + ' ' + 'MB' AS bkSize,
CONVERT(CHAR(12), s.backup_finish_date - s.backup_start_date, 114) AS TimeTaken,
s.backup_start_date,
s.backup_finish_date,
CASE s.[type]
WHEN 'D' THEN 'Full'
WHEN 'I' THEN 'Differential'
WHEN 'L' THEN 'Transaction Log'
END AS BackupType,
Is_copy_only
--CAST(s.first_lsn AS VARCHAR(50)) AS first_lsn,
--CAST(s.last_lsn AS VARCHAR(50)) AS last_lsn
FROM msdb.dbo.backupset s
INNER JOIN msdb.dbo.backupmediafamily m ON s.media_set_id = m.media_set_id
WHERE
--s.database_name NOT IN ('master', 'model', 'msdb', 'tempdb') AND -- Remove this line to see all the databases
--s.database_name = DB_NAME() AND -- Remove this line to see all the databases
(
s.[type] = 'D' -- Remove this line for hide Full
OR s.[type] = 'I' -- Remove this line for hide Differential
OR s.[type] = 'L' -- Remove this line for hide Transaction Log
)
ORDER BY backup_start_date DESC, backup_finish_date
GO
