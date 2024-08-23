DECLARE @source_database_name SYSNAME = DB_NAME()
DECLARE @dest_database_name SYSNAME = 'QReports-C10006573'
DECLARE @full_backup_n INT = 1 -- OFFSET: 0 - last full backup, 1 - previus full backup, etc ...
DECLARE @full_backup_start_date DATETIME
DECLARE @full_backup_finish_date DATETIME
DECLARE @full_backup_first_lsn NUMERIC(25,0)
DECLARE @full_backup_last_lsn NUMERIC(25,0)

SELECT 
@full_backup_start_date = backup_start_date,
@full_backup_finish_date = backup_finish_date,
@full_backup_first_lsn = first_lsn,
@full_backup_last_lsn = last_lsn
FROM msdb.dbo.backupset
WHERE database_name = @source_database_name AND recovery_model = 'FULL' AND is_copy_only = 0 AND type = 'D'
ORDER BY backup_start_date DESC OFFSET @full_backup_n ROWS FETCH NEXT 1 ROWS ONLY;

SELECT 
@source_database_name AS source_database_name, 
@full_backup_start_date AS full_backup_start_date, 
@full_backup_finish_date AS full_backup_finish_date, 
@full_backup_first_lsn AS full_backup_first_lsn, 
@full_backup_last_lsn AS full_backup_last_lsn, 
@dest_database_name AS destanation_database_name

SELECT
s.server_name,
s.database_name,
--s.recovery_model,
s.backup_start_date AS log_backup_start_date,
s.backup_finish_date AS log_backup_finish_date,
'RESTORE LOG [' + @dest_database_name + '] FROM DISK = N''' + m.physical_device_name + ''' WITH NORECOVERY, STATS = 5' AS [restore_log_query],
CAST(CAST(s.backup_size / 1000000 AS INT) AS VARCHAR(14)) + ' ' + 'MB' AS bkSize,
CONVERT(CHAR(12), s.backup_finish_date - s.backup_start_date, 114) AS TimeTaken,
Is_copy_only,
CAST(s.first_lsn AS VARCHAR(50)) AS first_lsn,
CAST(s.last_lsn AS VARCHAR(50)) AS last_lsn,
m.physical_device_name

FROM msdb.dbo.backupset s
INNER JOIN msdb.dbo.backupmediafamily m ON s.media_set_id = m.media_set_id
WHERE s.database_name = @source_database_name AND s.[type] = 'L' AND s.recovery_model = 'FULL' 
AND s.backup_start_date > @full_backup_start_date
AND s.last_lsn > @full_backup_last_lsn
--AND DATEDIFF(hh, s.backup_finish_date, GETDATE() ) < 3 * 24 -- for last 3 days
ORDER BY backup_start_date ASC
GO
