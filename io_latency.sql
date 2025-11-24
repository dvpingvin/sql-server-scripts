DECLARE @io_stats_history_prev TABLE  (
sample_ms bigint,
database_id int,
file_id int,
num_of_reads bigint,
num_of_bytes_read bigint,
num_of_writes bigint,
num_of_bytes_written bigint,
io_stall_read_ms bigint,
io_stall_write_ms bigint,
io_stall bigint, 
size_on_disk_bytes bigint, 
io_stall_queued_read_ms bigint, 
io_stall_queued_write_ms bigint
);

INSERT INTO @io_stats_history_prev 
SELECT 
sample_ms,
database_id,
file_id,
num_of_reads,
num_of_bytes_read,
num_of_writes,
num_of_bytes_written,
io_stall_read_ms,
io_stall_write_ms,
io_stall, 
size_on_disk_bytes, 
io_stall_queued_read_ms, 
io_stall_queued_write_ms
FROM sys.dm_io_virtual_file_stats(NULL, NULL);

WAITFOR DELAY '00:00:01';

DECLARE @io_stats_history TABLE (
sample_ms bigint,
database_id int,
file_id int,
num_of_reads bigint,
num_of_bytes_read bigint,
num_of_writes bigint,
num_of_bytes_written bigint,
io_stall_read_ms bigint,
io_stall_write_ms bigint,
io_stall bigint, 
size_on_disk_bytes bigint, 
io_stall_queued_read_ms bigint, 
io_stall_queued_write_ms bigint
);

INSERT INTO @io_stats_history 
SELECT 
sample_ms,
database_id,
file_id,
num_of_reads,
num_of_bytes_read,
num_of_writes,
num_of_bytes_written,
io_stall_read_ms,
io_stall_write_ms,
io_stall, 
size_on_disk_bytes, 
io_stall_queued_read_ms, 
io_stall_queued_write_ms
FROM sys.dm_io_virtual_file_stats(NULL, NULL);

SELECT 
GETDATE() AS [datetime],
DB_NAME(m.database_id) AS [db_name],
m.physical_name AS [file_name],
a.size_on_disk_bytes - b.size_on_disk_bytes AS [size_change_bytes],
a.num_of_reads - b.num_of_reads AS [num_of_reads],
a.num_of_bytes_read - b.num_of_bytes_read AS [num_of_bytes_read],
a.num_of_writes - b.num_of_writes AS [num_of_writes],
a.num_of_bytes_written - b.num_of_bytes_written AS [num_of_bytes_written],
a.io_stall_read_ms - b.io_stall_read_ms AS [io_stall_read_ms],
a.io_stall_write_ms - b.io_stall_write_ms AS [io_stall_write_ms],
a.io_stall - b.io_stall AS [io_stall_ms],
a.sample_ms - b.sample_ms AS [sample_ms]
FROM @io_stats_history a
INNER JOIN @io_stats_history_prev b ON a.database_id = b.database_id AND a.file_id = b.file_id
INNER JOIN sys.master_files m ON a.database_id = m.database_id AND a.file_id = m.file_id
WHERE 1 = 1
AND (a.num_of_reads - b.num_of_reads) + (a.num_of_writes - b.num_of_writes) + (a.io_stall - b.io_stall) <> 0
AND m.database_id > 4
ORDER BY io_stall_ms DESC;
