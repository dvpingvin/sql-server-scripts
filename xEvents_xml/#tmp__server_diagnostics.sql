DROP TABLE IF EXISTS #tmp__server_diagnostics;
-- Создаем временную таблицу для хранения результатов
CREATE TABLE #tmp__server_diagnostics (
    create_time DATETIME,
    component_type sysname,
    component_name sysname,
    state INT,
    state_desc sysname,
    data XML
);

-- Вставляем результаты sp_server_diagnostics во временную таблицу
INSERT INTO #tmp__server_diagnostics (
    create_time,
    component_type,
    component_name,
    state,
    state_desc,
    data
)
EXEC sp_server_diagnostics;

-- Проверяем, что данные записались
--SELECT [data] FROM #tmp__server_diagnostics WHERE component_name = 'system';

-- Базовый парсинг всех атрибутов из XML компонента system
SELECT 
    create_time,
    data.value('(/system/@spinlockBackoffs)[1]', 'INT') AS spinlockBackoffs,
    data.value('(/system/@sickSpinlockType)[1]', 'VARCHAR(50)') AS sickSpinlockType,
    data.value('(/system/@sickSpinlockTypeAfterAv)[1]', 'VARCHAR(50)') AS sickSpinlockTypeAfterAv,
    data.value('(/system/@latchWarnings)[1]', 'INT') AS latchWarnings,
    data.value('(/system/@isAccessViolationOccurred)[1]', 'BIT') AS isAccessViolationOccurred,
    data.value('(/system/@writeAccessViolationCount)[1]', 'INT') AS writeAccessViolationCount,
    data.value('(/system/@totalDumpRequests)[1]', 'INT') AS totalDumpRequests,
    data.value('(/system/@intervalDumpRequests)[1]', 'INT') AS intervalDumpRequests,
    data.value('(/system/@nonYieldingTasksReported)[1]', 'INT') AS nonYieldingTasksReported,
    data.value('(/system/@pageFaults)[1]', 'INT') AS pageFaults,
    data.value('(/system/@systemCpuUtilization)[1]', 'INT') AS systemCpuUtilization,
    data.value('(/system/@sqlCpuUtilization)[1]', 'INT') AS sqlCpuUtilization,
    data.value('(/system/@BadPagesDetected)[1]', 'INT') AS BadPagesDetected,
    data.value('(/system/@BadPagesFixed)[1]', 'INT') AS BadPagesFixed,
    data.value('(/system/@LastBadPageAddress)[1]', 'VARCHAR(50)') AS LastBadPageAddress
FROM #tmp__server_diagnostics 
WHERE component_name = 'system'
ORDER BY create_time DESC;

-- Базовый парсинг основных атрибутов
SELECT 
    create_time,
    data.value('(/resource/@lastNotification)[1]', 'varchar(100)') AS last_notification,
    data.value('(/resource/@outOfMemoryExceptions)[1]', 'int') AS out_of_memory_exceptions,
    data.value('(/resource/@isAnyPoolOutOfMemory)[1]', 'int') AS is_any_pool_out_of_memory,
    data.value('(/resource/@processOutOfMemoryPeriod)[1]', 'int') AS process_out_of_memory_period,
    
    -- Парсинг Memory Report: Process/System Counts
    data.value('(/resource/memoryReport[@name="Process/System Counts"]/entry[@description="Available Physical Memory"]/@value)[1]', 'bigint') AS available_physical_memory,
    data.value('(/resource/memoryReport[@name="Process/System Counts"]/entry[@description="Available Virtual Memory"]/@value)[1]', 'bigint') AS available_virtual_memory,
    data.value('(/resource/memoryReport[@name="Process/System Counts"]/entry[@description="Available Paging File"]/@value)[1]', 'bigint') AS available_paging_file,
    data.value('(/resource/memoryReport[@name="Process/System Counts"]/entry[@description="Working Set"]/@value)[1]', 'bigint') AS working_set,
    data.value('(/resource/memoryReport[@name="Process/System Counts"]/entry[@description="Percent of Committed Memory in WS"]/@value)[1]', 'int') AS percent_committed_memory_in_ws,
    data.value('(/resource/memoryReport[@name="Process/System Counts"]/entry[@description="Page Faults"]/@value)[1]', 'bigint') AS page_faults,
    data.value('(/resource/memoryReport[@name="Process/System Counts"]/entry[@description="System physical memory high"]/@value)[1]', 'bit') AS system_physical_memory_high,
    data.value('(/resource/memoryReport[@name="Process/System Counts"]/entry[@description="System physical memory low"]/@value)[1]', 'bit') AS system_physical_memory_low,
    data.value('(/resource/memoryReport[@name="Process/System Counts"]/entry[@description="Process physical memory low"]/@value)[1]', 'bit') AS process_physical_memory_low,
    data.value('(/resource/memoryReport[@name="Process/System Counts"]/entry[@description="Process virtual memory low"]/@value)[1]', 'bit') AS process_virtual_memory_low,
    
    -- Парсинг Memory Report: Memory Manager
    data.value('(/resource/memoryReport[@name="Memory Manager"]/entry[@description="VM Reserved"]/@value)[1]', 'bigint') AS vm_reserved_kb,
    data.value('(/resource/memoryReport[@name="Memory Manager"]/entry[@description="VM Committed"]/@value)[1]', 'bigint') AS vm_committed_kb,
    data.value('(/resource/memoryReport[@name="Memory Manager"]/entry[@description="Locked Pages Allocated"]/@value)[1]', 'bigint') AS locked_pages_allocated,
    data.value('(/resource/memoryReport[@name="Memory Manager"]/entry[@description="Large Pages Allocated"]/@value)[1]', 'bigint') AS large_pages_allocated,
    data.value('(/resource/memoryReport[@name="Memory Manager"]/entry[@description="Emergency Memory"]/@value)[1]', 'int') AS emergency_memory_kb,
    data.value('(/resource/memoryReport[@name="Memory Manager"]/entry[@description="Emergency Memory In Use"]/@value)[1]', 'int') AS emergency_memory_in_use_kb,
    data.value('(/resource/memoryReport[@name="Memory Manager"]/entry[@description="Target Committed"]/@value)[1]', 'bigint') AS target_committed_kb,
    data.value('(/resource/memoryReport[@name="Memory Manager"]/entry[@description="Current Committed"]/@value)[1]', 'bigint') AS current_committed_kb,
    data.value('(/resource/memoryReport[@name="Memory Manager"]/entry[@description="Pages Allocated"]/@value)[1]', 'bigint') AS pages_allocated,
    data.value('(/resource/memoryReport[@name="Memory Manager"]/entry[@description="Pages Reserved"]/@value)[1]', 'bigint') AS pages_reserved,
    data.value('(/resource/memoryReport[@name="Memory Manager"]/entry[@description="Pages Free"]/@value)[1]', 'bigint') AS pages_free,
    data.value('(/resource/memoryReport[@name="Memory Manager"]/entry[@description="Pages In Use"]/@value)[1]', 'bigint') AS pages_in_use,
    data.value('(/resource/memoryReport[@name="Memory Manager"]/entry[@description="Page Alloc Potential"]/@value)[1]', 'bigint') AS page_alloc_potential,
    data.value('(/resource/memoryReport[@name="Memory Manager"]/entry[@description="NUMA Growth Phase"]/@value)[1]', 'int') AS numa_growth_phase,
    data.value('(/resource/memoryReport[@name="Memory Manager"]/entry[@description="Last OOM Factor"]/@value)[1]', 'int') AS last_oom_factor,
    data.value('(/resource/memoryReport[@name="Memory Manager"]/entry[@description="Last OS Error"]/@value)[1]', 'int') AS last_os_error
FROM #tmp__server_diagnostics 
WHERE component_name = 'resource';

-- Извлечение основных атрибутов queryProcessing
SELECT 
    create_time,
    data.value('(/queryProcessing/@maxWorkers)[1]', 'INT') AS max_workers,
    data.value('(/queryProcessing/@workersCreated)[1]', 'INT') AS workers_created,
    data.value('(/queryProcessing/@workersIdle)[1]', 'INT') AS workers_idle,
    data.value('(/queryProcessing/@tasksCompletedWithinInterval)[1]', 'INT') AS tasks_completed,
    data.value('(/queryProcessing/@pendingTasks)[1]', 'INT') AS pending_tasks,
    data.value('(/queryProcessing/@oldestPendingTaskWaitingTime)[1]', 'INT') AS oldest_pending_wait_time,
    data.value('(/queryProcessing/@hasUnresolvableDeadlockOccurred)[1]', 'BIT') AS has_unresolvable_deadlock,
    data.value('(/queryProcessing/@hasDeadlockedSchedulersOccurred)[1]', 'BIT') AS has_deadlocked_schedulers
FROM #tmp__server_diagnostics 
WHERE component_name = 'query_processing';


-- Детальный парсинг io_subsystem с обработкой всех возможных полей
SELECT 
    create_time,
    component_name,
    state_desc,
    
    -- Основные счетчики
    data.value('(/ioSubsystem/@ioLatchTimeouts)[1]', 'INT') AS ioLatchTimeouts,
    data.value('(/ioSubsystem/@intervalLongIos)[1]', 'INT') AS interval_long_ios,
    data.value('(/ioSubsystem/@totalLongIos)[1]', 'INT') AS total_long_ios,
    
    -- Информация о дисках (если есть в XML)
    data.value('(/ioSubsystem/disk/@name)[1]', 'NVARCHAR(50)') AS disk_name,
    data.value('(/ioSubsystem/disk/@avgRead)[1]', 'DECIMAL(10,2)') AS avg_read,
    data.value('(/ioSubsystem/disk/@avgWrite)[1]', 'DECIMAL(10,2)') AS avg_write,
    data.value('(/ioSubsystem/disk/@avgTransfer)[1]', 'DECIMAL(10,2)') AS avg_transfer,
    
    -- Дополнительная информация о дисках
    data.value('(/ioSubsystem/disk/@reads)[1]', 'BIGINT') AS reads_count,
    data.value('(/ioSubsystem/disk/@writes)[1]', 'BIGINT') AS writes_count,
    data.value('(/ioSubsystem/disk/@totalBytes)[1]', 'BIGINT') AS total_bytes,
    
    -- Время ожидания
    data.value('(/ioSubsystem/disk/@avgReadStall)[1]', 'INT') AS avg_read_stall,
    data.value('(/ioSubsystem/disk/@avgWriteStall)[1]', 'INT') AS avg_write_stall
    
    -- Сам XML для отладки
    --CAST(data AS NVARCHAR(MAX)) AS raw_xml

FROM #tmp__server_diagnostics 
WHERE component_name = 'io_subsystem'
ORDER BY create_time DESC;

-- Парсинг всех событий из компонента events
SELECT 
    create_time,
    component_name,
    -- Основная информация о событии
    event.value('@name', 'NVARCHAR(100)') AS event_name,
    event.value('@package', 'NVARCHAR(50)') AS event_package,
    event.value('@timestamp', 'DATETIME2') AS event_timestamp,
    
    -- Получаем данные события в XML для дальнейшего разбора
    event.query('.') AS event_data
FROM #tmp__server_diagnostics
CROSS APPLY data.nodes('/events/session/RingBufferTarget/event') AS t(event)
WHERE component_name = 'events';

-- Когда закончите работу, можно удалить временную таблицу
DROP TABLE IF EXISTS #tmp__server_diagnostics;
