SELECT
DB_NAME(re.database_id) + ' (id:' + CONVERT(VARCHAR(5), re.database_id) + ')' AS [database]
,re.command
,[sql_text_xml] =
(SELECT REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
text,
NCHAR(1),N'?'),NCHAR(2),N'?'),NCHAR(3),N'?'),NCHAR(4),N'?'),NCHAR(5),N'?'),NCHAR(6),N'?'),NCHAR(7),N'?'),NCHAR(8),N'?'),NCHAR(11),N'?'),NCHAR(12),N'?'),NCHAR(14),N'?'),NCHAR(15),N'?'),NCHAR(16),N'?'),NCHAR(17),N'?'),NCHAR(18),N'?'),NCHAR(19),N'?'),NCHAR(20),N'?'),NCHAR(21),N'?'),NCHAR(22),N'?'),NCHAR(23),N'?'),NCHAR(24),N'?'),NCHAR(25),N'?'),NCHAR(26),N'?'),NCHAR(27),N'?'),NCHAR(28),N'?'),NCHAR(29),N'?'),NCHAR(30),N'?'),NCHAR(31),N'?')
FROM sys.dm_exec_sql_text(re.sql_handle)
FOR XML PATH(''), TYPE)
,re.status
--,re.wait_type
--,re.reads
--,re.writes
--,re.logical_reads
,re.percent_complete
,re.total_elapsed_time  / 1000 / 60 AS requst_duration_min
,re.estimated_completion_time/60000 AS completion_time
,re.start_time AS start_time
,re.session_id
,at.transaction_id
 
FROM sys.dm_exec_requests AS re WITH(nolock) LEFT JOIN sys.dm_tran_active_transactions AS at WITH(nolock) ON re.transaction_id = at.transaction_id
WHERE 
(re.session_id > 50 AND re.session_id <> @@spid AND at.transaction_type IN (1, 4) AND DATEDIFF(MINUTE, at.transaction_begin_time, GETDATE()) > 5) -- more than 5 minutes
OR command IN ('BACKUP DATABASE', 'RESTORE DATABASE', 'BACKUP LOG', 'RESTORE LOG', 'AUTOSHRINK') -- backup/restore, shrint
ORDER BY transaction_begin_time ASC
