DROP TABLE IF EXISTS #SpaceUsed
CREATE TABLE #SpaceUsed
(
database_id SMALLINT NOT NULL,
file_id SMALLINT NOT NULL,
space_used DECIMAL(15,3) NOT NULL,
PRIMARY KEY(database_id, file_id)
);
EXEC master..sp_MSforeachdb
N'USE[?];
INSERT INTO #SpaceUsed(database_id, file_id, space_used)
SELECT DB_ID(''?''), file_id,
(size - CONVERT(INT,FILEPROPERTY(name, ''SpaceUsed''))) / 128.
FROM sys.database_files
WHERE type = 1;';
SELECT
d.database_id, d.name, d.recovery_model_desc
,d.state_desc, d.log_reuse_wait_desc, m.physical_name
--,[size] AS [size in 8k pages]
,CAST (s.space_used  AS VARCHAR (10)) + ' MB' AS [Space Used]
,CAST (CAST ([size] / 131072.0 AS DECIMAL(17,2))  AS VARCHAR (10)) + ' GB' AS [Current size]
,CASE [max_size]
WHEN -1 THEN 'Unlimited'
WHEN 268435456 THEN '2 TB Limited'
ELSE CAST (CAST ([max_size] / 131072.0 AS DECIMAL(17,2))  AS VARCHAR (10)) + ' GB'
END AS [Max size]
,[is_percent_growth] AS [Is Percent Growth]
,CASE [is_percent_growth]
WHEN 0 THEN CAST ([growth]*8/1024 AS VARCHAR(10)) + ' MB'
WHEN 1 THEN CAST ([growth] AS VARCHAR(10)) + ' %'
END AS [Growth Step]
FROM
sys.databases d WITH (NOLOCK)
JOIN sys.master_files m WITH (NOLOCK) ON
d.database_id = m.database_id
LEFT OUTER JOIN #SpaceUsed s ON
s.database_id = m.database_id AND
s.file_id = m.file_id
WHERE m.type = 1
-- AND [name] = '<db_name>';
ORDER BY
d.database_id;
