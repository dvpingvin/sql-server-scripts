SELECT
s.server_name,
s.database_name,
--s.recovery_model,
s.backup_start_date,
s.backup_finish_date,
'RESTORE LOG [' + DB_NAME() + '] FROM DISK = N''' + m.physical_device_name + ''' WITH NORECOVERY, STATS = 5' AS [restore_log_query],
CAST(CAST(s.backup_size / 1000000 AS INT) AS VARCHAR(14)) + ' ' + 'MB' AS bkSize,
CONVERT(CHAR(12), s.backup_finish_date - s.backup_start_date, 114) AS TimeTaken,
Is_copy_only,
CAST(s.first_lsn AS VARCHAR(50)) AS first_lsn,
CAST(s.last_lsn AS VARCHAR(50)) AS last_lsn,
m.physical_device_name
FROM msdb.dbo.backupset s
INNER JOIN msdb.dbo.backupmediafamily m ON s.media_set_id = m.media_set_id
WHERE s.database_name = DB_NAME() AND s.[type] = 'L' AND s.recovery_model = 'FULL' AND DATEDIFF(hh, s.backup_finish_date, GETDATE() ) < 3 * 24 -- for last 3 days
ORDER BY backup_start_date ASC
GO
