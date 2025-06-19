--исходник здесь https://github.com/Constantine-SRV/IO_Virtual_File_Stats_history/blob/main/README_RUS.md там же дополнительные запросы по каждому файлу и с группировкой по 10 минут

--создать таблицу в мастере
CREATE TABLE [dbo].[tbl_IO_Virtual_File_Stats](
    [RecordID] [bigint] IDENTITY(1,1) NOT NULL,
    [database_id] [smallint] NULL,
    [file_id] [smallint] NULL,
    [sample_ms] [bigint] NULL,
    [num_of_reads] [bigint] NULL,
    [num_of_bytes_read] [bigint] NULL,
    [io_stall_read_ms] [bigint] NULL,
    [num_of_writes] [bigint] NULL,
    [num_of_bytes_written] [bigint] NULL,
    [io_stall_write_ms] [bigint] NULL,
    [io_stall] [bigint] NULL,
    [io_stall_queued_read_ms] [bigint] NULL,
    [io_stall_queued_write_ms] [bigint] NULL,
    [dt] [smalldatetime] NULL,
CONSTRAINT [PK_tbl_IO_Virtual_File_Stats] PRIMARY KEY CLUSTERED 
(
    [RecordID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, 
    DATA_COMPRESSION = PAGE 
   ) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[tbl_IO_Virtual_File_Stats] ADD  DEFAULT (getdate()) FOR [dt]
GO



--включить сбор данных  цикл, выполняется каждую минуту в 00 секунд


--use db with tbl_IO_Virtual_File_Stats
DECLARE @maxTbSizeMb INT = 20;      -- Maximum allowed size in MB before cleanup

DECLARE @waitForTime NVARCHAR(8);    -- Variable to store the next execution time
DECLARE @msgTxt NVARCHAR(100);       -- Variable to store the message text
DECLARE @tbSize BIGINT;              -- Variable to store the table size in MB

WHILE 1 = 1
BEGIN
    -- Calculate the next full minute
    SET @waitForTime = CONVERT(CHAR(8), DATEADD(SECOND, 60 - DATEPART(SECOND, GETDATE()), GETDATE()), 108);
    
    -- Form the message to notify about the next execution
    SET @msgTxt = 'Next execution at: ' + @waitForTime;
    
    -- Print the message immediately
    RAISERROR(@msgTxt, 0, 1) WITH NOWAIT;
    
    -- Wait until the next full minute
    WAITFOR TIME @waitForTime;

    -- Insert the data into the table
    INSERT INTO tbl_IO_Virtual_File_Stats (database_id, file_id, sample_ms, num_of_reads, num_of_bytes_read, io_stall_read_ms,
                                           num_of_writes, num_of_bytes_written, io_stall_write_ms, io_stall,
                                           io_stall_queued_read_ms, io_stall_queued_write_ms)
    SELECT 
        database_id,
        file_id,
        sample_ms,
        num_of_reads,
        num_of_bytes_read,
        io_stall_read_ms,
        num_of_writes,
        num_of_bytes_written,
        io_stall_write_ms,
        io_stall,
        io_stall_queued_read_ms,
        io_stall_queued_write_ms
    FROM sys.dm_io_virtual_file_stats(NULL, NULL);

    -- Calculate the current table size in MB
    SELECT @tbSize = SUM(reserved_page_count) * 8 / 1024
    FROM sys.dm_db_partition_stats
    WHERE object_id = OBJECT_ID('tbl_IO_Virtual_File_Stats');
    
    -- Check if the table size exceeds the maximum allowed size
    IF @tbSize > @maxTbSizeMb
    BEGIN
        -- Delete 10% of the oldest records
        DELETE TOP (10) PERCENT FROM tbl_IO_Virtual_File_Stats;  -- if only one index

        -- Notify about the deletion
        SET @msgTxt = '!----- Deleted top 10prc of records --------- ' + CAST(@@ROWCOUNT AS NVARCHAR) + '  records at ' + CONVERT(VARCHAR(5), GETDATE(), 108);
        RAISERROR(@msgTxt, 0, 1) WITH NOWAIT;
        
        -- Rebuild the primary key index after deletion
        ALTER INDEX [PK_tbl_IO_Virtual_File_Stats] ON [dbo].[tbl_IO_Virtual_File_Stats] 
        REBUILD PARTITION = ALL WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, ONLINE = OFF, DATA_COMPRESSION = PAGE ,ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON);
    END;
END;





--запрос посмотреть задержки
WITH FileStatsWithLag AS (
    SELECT
        vfs.RecordID,
        vfs.database_id,
        vfs.file_id,
        vfs.sample_ms,
        vfs.num_of_reads,
        vfs.num_of_writes,
        vfs.num_of_bytes_read,
        vfs.num_of_bytes_written,
        vfs.io_stall_read_ms,
        vfs.io_stall_write_ms,
        vfs.io_stall,
        vfs.dt,
        mf.physical_name,
        DB_NAME(vfs.database_id) AS db_name,
        LEFT(mf.physical_name, 1) AS DriveLetter,
        
        LAG(vfs.num_of_reads) OVER (PARTITION BY vfs.database_id, vfs.file_id ORDER BY vfs.dt) AS prev_num_of_reads,
        LAG(vfs.num_of_writes) OVER (PARTITION BY vfs.database_id, vfs.file_id ORDER BY vfs.dt) AS prev_num_of_writes,
        LAG(vfs.num_of_bytes_read) OVER (PARTITION BY vfs.database_id, vfs.file_id ORDER BY vfs.dt) AS prev_num_of_bytes_read,
        LAG(vfs.num_of_bytes_written) OVER (PARTITION BY vfs.database_id, vfs.file_id ORDER BY vfs.dt) AS prev_num_of_bytes_written,
        LAG(vfs.io_stall_read_ms) OVER (PARTITION BY vfs.database_id, vfs.file_id ORDER BY vfs.dt) AS prev_io_stall_read_ms,
        LAG(vfs.io_stall_write_ms) OVER (PARTITION BY vfs.database_id, vfs.file_id ORDER BY vfs.dt) AS prev_io_stall_write_ms,
        LAG(vfs.io_stall) OVER (PARTITION BY vfs.database_id, vfs.file_id ORDER BY vfs.dt) AS prev_io_stall
    FROM tbl_IO_Virtual_File_Stats vfs
    JOIN sys.master_files mf
        ON vfs.database_id = mf.database_id
        AND vfs.file_id = mf.file_id
)
SELECT
    DriveLetter AS [Drive],
    dt,
    
    SUM(num_of_reads - prev_num_of_reads) AS [Reads per Minute],
    SUM(num_of_writes - prev_num_of_writes) AS [Writes per Minute],
    
    CAST(SUM(num_of_bytes_read - prev_num_of_bytes_read) / (1024.0 * 1024.0) AS NUMERIC(12,2)) AS [Total Bytes Read per Minute (MB)],
    CAST(SUM(num_of_bytes_written - prev_num_of_bytes_written) / (1024.0 * 1024.0) AS NUMERIC(12,2)) AS [Total Bytes Written per Minute (MB)],
    
    CAST(SUM(num_of_bytes_read - prev_num_of_bytes_read) / (60.0 * 1024.0 * 1024.0) AS NUMERIC(12,2)) AS [Read Throughput (MB/s)],
    CAST(SUM(num_of_bytes_written - prev_num_of_bytes_written) / (60.0 * 1024.0 * 1024.0) AS NUMERIC(12,2)) AS [Write Throughput (MB/s)],
    
    IIF(SUM(num_of_reads - prev_num_of_reads) = 0, 0, 
    SUM(io_stall_read_ms - prev_io_stall_read_ms) / SUM(num_of_reads - prev_num_of_reads)) AS [Avg Read Latency (ms)],
    
    IIF(SUM(num_of_writes - prev_num_of_writes) = 0, 0, 
    SUM(io_stall_write_ms - prev_io_stall_write_ms) / SUM(num_of_writes - prev_num_of_writes)) AS [Avg Write Latency (ms)],
    
    IIF(SUM((num_of_reads - prev_num_of_reads) + (num_of_writes - prev_num_of_writes)) = 0, 0, 
    SUM(io_stall - prev_io_stall) / SUM((num_of_reads - prev_num_of_reads) + (num_of_writes - prev_num_of_writes))) AS [Avg Overall Latency (ms)]
    
FROM FileStatsWithLag
WHERE prev_num_of_reads IS NOT NULL
  AND prev_num_of_writes IS NOT NULL
GROUP BY DriveLetter, dt
--HAVING IIF(SUM((num_of_reads - prev_num_of_reads) + (num_of_writes - prev_num_of_writes)) = 0, 0, SUM(io_stall - prev_io_stall) / SUM((num_of_reads - prev_num_of_reads) + (num_of_writes - prev_num_of_writes))) > 0
ORDER BY dt DESC, DriveLetter;
