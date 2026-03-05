/* 
-- Загрузка данных из ring_buffer (то же самое содержится в *.xel)
DROP TABLE IF EXISTS #tmp_xe_event_data;

;WITH RingBufferData AS 
	(SELECT CAST(st.target_data AS XML) AS ring_buffer_xml, p.name
	FROM sys.dm_xe_session_targets st
	LEFT JOIN sys.dm_xe_packages p ON st.target_package_guid = p.guid
	WHERE target_name = 'ring_buffer')
SELECT 
    event_data.value('@name', 'NVARCHAR(100)') AS object_name,
	CASE 
		WHEN rbd.name IS NOT NULL THEN rbd.name
		ELSE event_data.value('@package', 'NVARCHAR(50)') -- Закомментировать для ускорения (за счёт того, что не парсим XML для получения package_name, если не нашли через sys.dm_xe_packages)
	END AS package_name,
    event_data.value('@timestamp', 'DATETIME2') AS timestamp_utc,
    event_data.query('.') AS event_data,
	'ring_buffer' AS file_name
INTO #tmp_xe_event_data
FROM RingBufferData rbd
CROSS APPLY rbd.ring_buffer_xml.nodes('//RingBufferTarget/event') AS t(event_data);
*/

-- Загрузка данных из *.xel
DROP TABLE IF EXISTS #tmp_xe_event_data;

SELECT 
	object_name,
	CASE 
		WHEN p.name IS NOT NULL THEN p.name
		--ELSE CAST(event_data AS XML).value('(//event/@package)[1]', 'NVARCHAR(50)') -- Закомментировать для ускорения (за счёт того, что не парсим XML для получения package_name, если не нашли через sys.dm_xe_packages)
	END AS package_name,
	timestamp_utc, 
	CAST(event_data AS XML) AS event_data, 
	file_name
INTO #tmp_xe_event_data
FROM sys.fn_xe_file_target_read_file('*.xel', NULL, NULL, NULL) ft
LEFT JOIN sys.dm_xe_packages p ON ft.package_guid = p.guid;

SELECT * FROM #tmp_xe_event_data 
WHERE 1=1
AND timestamp_utc > DATEADD(day, -2, GETUTCDATE()) -- За последние 2 суток
AND object_name IN (
    'xml_deadlock_report',                                   -- Отчеты о дедлоках (КРИТИЧНО)
    'sp_server_diagnostics_component_result'                 -- Результаты диагностики сервера (ВАЖНО)
    --'resource_monitor_ring_buffer_recorded',                 -- Мониторинг памяти (ОЧЕНЬ ВАЖНО)
    --'memory_broker_ring_buffer_recorded',                    -- Распределитель памяти (ОЧЕНЬ ВАЖНО)
    --'spinlock_backoff'                                       -- Ожидания на spinlock (ВАЖНО)
)

/*
-- Справочник объектов (object_name):
-- ========== МОНИТОРИНГ ПАМЯТИ И РЕСУРСОВ ==========
    'resource_monitor_ring_buffer_recorded',                 -- Мониторинг памяти (ОЧЕНЬ ВАЖНО)
    'memory_broker_ring_buffer_recorded',                    -- Распределитель памяти (ОЧЕНЬ ВАЖНО)
    'memory_node_oom_ring_buffer_recorded',                  -- Нехватка памяти на узле
    'memory_pressure_state_change',                          -- Изменение давления памяти

-- ========== ПЛАНИРОВЩИК И ПРОЦЕССЫ ==========
    'scheduler_monitor_system_health_ring_buffer_recorded', -- Состояние планировщиков (ОЧЕНЬ ВАЖНО)
    'scheduler_monitor_deadlock_ring_buffer_recorded',      -- Дедлоки в планировщике
    'scheduler_monitor_nonpreemptive_waits',                -- Невытесняющие ожидания
    'scheduler_monitor_preemptive_waits',                   -- Вытесняющие ожидания

-- ========== SPINLOCK ==========
    'spinlock_backoff',                                      -- Ожидания на spinlock (ОЧЕНЬ ВАЖНО)
    'spinlock_overflow',                                     -- Переполнение spinlock

-- ========== ОШИБКИ И ИСКЛЮЧЕНИЯ ==========
    'error_reported',                                        -- Сообщения об ошибках (ОЧЕНЬ ВАЖНО)
    'exception',                                             -- Исключения
    'attention',                                             -- Отмена запроса клиентом
    'abort_query_worker',                                    -- Прерывание запроса
    'security_error_ring_buffer_recorded',                   -- Ошибки безопасности

-- ========== БЛОКИРОВКИ И КОНКУРЕНТНОСТЬ ==========
    'lock_deadlock',                                         -- Событие дедлока
    'lock_deadlock_chain',                                   -- Цепочка дедлока
    'lock_timeout',                                          -- Таймаут блокировки
    'lock_waits',                                            -- Ожидания блокировок

-- ========== СОЕДИНЕНИЯ, СЕССИИ И СВЯЗЬ ==========
    'connect',                                               -- Подключение
    'disconnect',                                            -- Отключение
    'login',                                                 -- Вход в систему
    'logout',                                                -- Выход из системы
    'connection_ring_buffer_recorded',                       -- Кольцевой буфер соединений
    'session_connect',                                       -- Подключение сессии
    'connectivity_ring_buffer_recorded',                     -- Проблемы с подключениями

-- ========== ВВОД-ВЫВОД ==========
    'io_completion',                                         -- Завершение операций ввода-вывода
    'io_request',                                            -- Запросы ввода-вывода
    'file_write',                                            -- Запись в файл
    'file_read',                                             -- Чтение из файла
    'async_io_completion',                                   -- Асинхронный ввод-вывод

-- ========== СЕРВИСЫ И КОМПОНЕНТЫ ==========
    'service_broker_ring_buffer_recorded',                   -- Service Broker
    'fulltext_health_ring_buffer_recorded',                  -- Полнотекстовый поиск
    'sql_process_health_ring_buffer_recorded',               -- Состояние процесса SQL Server
    'telemetry_events',                                      -- Телеметрия

-- ========== БЕЗОПАСНОСТЬ ==========
    'audit_login',                                           -- Аудит входа
    'audit_logout',                                          -- Аудит выхода
    'audit_login_change_password',                           -- Изменение пароля
    'audit_schema_object_access',                            -- Доступ к объектам схемы

-- ========== ТРАНЗАКЦИИ И ВОССТАНОВЛЕНИЕ ==========
    'transaction_log',                                       -- Операции с логом транзакций
    'recovery_progress',                                     -- Прогресс восстановления
    'checkpoint_begin',                                      -- Начало контрольной точки
    'checkpoint_end',                                        -- Окончание контрольной точки

-- ========== TEMPDB И IN-MEMORY ==========
    'tempdb_health_ring_buffer_recorded',                    -- Состояние TempDB
    'gc_ring_buffer_recorded',                               -- Сборка мусора (In-Memory OLTP)

-- ========== ALWAYSON И КЛАСТЕРИЗАЦИЯ ==========
    'alwayson_health_ring_buffer_recorded',                  -- Состояние AlwaysOn
    'hadr_health_ring_buffer_recorded',                      -- Health AlwaysOn
    'cluster_health_ring_buffer_recorded'                    -- Состояние кластера
*/

-- Парсинг scheduler_monitor_system_health_ring_buffer_recorded
SELECT 
    -- Данные из элементов data
    CAST(event_data AS XML).value('(/event/@timestamp)[1]', 'DATETIME2') AS event_timestamp_utc,
    CAST(event_data AS XML).value('(/event/data[@name="id"]/value)[1]', 'INT') AS id,
    CAST(event_data AS XML).value('(/event/data[@name="timestamp"]/value)[1]', 'BIGINT') AS event_timestamp_value,
    CAST(event_data AS XML).value('(/event/data[@name="process_utilization"]/value)[1]', 'INT') AS process_utilization,
    CAST(event_data AS XML).value('(/event/data[@name="system_idle"]/value)[1]', 'INT') AS system_idle,
    CAST(event_data AS XML).value('(/event/data[@name="user_mode_time"]/value)[1]', 'BIGINT') AS user_mode_time,
    CAST(event_data AS XML).value('(/event/data[@name="kernel_mode_time"]/value)[1]', 'BIGINT') AS kernel_mode_time,
    CAST(event_data AS XML).value('(/event/data[@name="page_faults"]/value)[1]', 'BIGINT') AS page_faults,
    CAST(event_data AS XML).value('(/event/data[@name="working_set_delta"]/value)[1]', 'BIGINT') AS working_set_delta,
    CAST(event_data AS XML).value('(/event/data[@name="memory_utilization"]/value)[1]', 'INT') AS memory_utilization,
    CAST(event_data AS XML) AS xml -- Полный XML для отладки
FROM #tmp_xe_event_data
WHERE object_name = 'scheduler_monitor_system_health_ring_buffer_recorded'
ORDER BY event_timestamp_utc

-- Парсинг memory_broker_ring_buffer_recorded
SELECT 
    -- Данные из элементов data
    CAST(event_data AS XML).value('(/event/@timestamp)[1]', 'DATETIME2') AS event_timestamp_utc,
    CAST(event_data AS XML).value('(/event/data[@name="id"]/value)[1]', 'INT') AS id,
    CAST(event_data AS XML).value('(/event/data[@name="timestamp"]/value)[1]', 'BIGINT') AS event_timestamp_value,
    CAST(event_data AS XML).value('(/event/data[@name="pool_metadata_id"]/value)[1]', 'INT') AS pool_metadata_id,
    CAST(event_data AS XML).value('(/event/data[@name="delta_time"]/value)[1]', 'BIGINT') AS delta_time,
    CAST(event_data AS XML).value('(/event/data[@name="memory_ratio"]/value)[1]', 'INT') AS memory_ratio,
    CAST(event_data AS XML).value('(/event/data[@name="new_target"]/value)[1]', 'BIGINT') AS new_target,
    CAST(event_data AS XML).value('(/event/data[@name="overall"]/value)[1]', 'BIGINT') AS overall,
    CAST(event_data AS XML).value('(/event/data[@name="rate"]/value)[1]', 'INT') AS rate,
    CAST(event_data AS XML).value('(/event/data[@name="currently_predicated"]/value)[1]', 'BIGINT') AS currently_predicated,
    CAST(event_data AS XML).value('(/event/data[@name="currently_allocated"]/value)[1]', 'BIGINT') AS currently_allocated,
    CAST(event_data AS XML).value('(/event/data[@name="previously_allocated"]/value)[1]', 'BIGINT') AS previously_allocated,
    CAST(event_data AS XML).value('(/event/data[@name="broker"]/value)[1]', 'NVARCHAR(100)') AS broker,
    CAST(event_data AS XML).value('(/event/data[@name="notification"]/value)[1]', 'NVARCHAR(50)') AS notification,
    CAST(event_data AS XML) AS xml -- Полный XML для отладки
FROM #tmp_xe_event_data
WHERE object_name = 'memory_broker_ring_buffer_recorded'
ORDER BY event_timestamp_utc

-- Парсинг SSMBackup2WAOperationalXevent
SELECT 
    -- Данные из элементов data
    CAST(event_data AS XML).value('(/event/@timestamp)[1]', 'DATETIME2') AS event_timestamp_utc,
    CAST(event_data AS XML).value('(/event/data[@name="database_id"]/value)[1]', 'INT') AS database_id,
    CAST(event_data AS XML).value('(/event/data[@name="current_stage"]/value)[1]', 'INT') AS current_stage,
    CAST(event_data AS XML).value('(/event/data[@name="current_stage"]/text)[1]', 'NVARCHAR(50)') AS current_stage_desc,
    CAST(event_data AS XML).value('(/event/data[@name="database_name"]/value)[1]', 'NVARCHAR(128)') AS database_name,
    CAST(event_data AS XML).value('(/event/data[@name="summary"]/value)[1]', 'NVARCHAR(MAX)') AS summary,
    CAST(event_data AS XML).value('(/event/data[@name="activityId"]/value)[1]', 'UNIQUEIDENTIFIER') AS activityId,
    CAST(event_data AS XML).value('(/event/data[@name="message"]/value)[1]', 'NVARCHAR(MAX)') AS message,
    
    -- Данные из элементов action (если нужны)
    CAST(event_data AS XML).value('(/event/action[@name="event_sequence"]/value)[1]', 'BIGINT') AS event_sequence,
    CAST(event_data AS XML).value('(/event/action[@name="attach_activity_id"]/value)[1]', 'NVARCHAR(50)') AS attach_activity_id,
    
    CAST(event_data AS XML) AS xml -- Полный XML для отладки
FROM #tmp_xe_event_data
WHERE object_name = 'SSMBackup2WAOperationalXevent'
ORDER BY event_timestamp_utc

-- Парсинг loggerEvent
SELECT 
    -- Данные из элементов data
    CAST(event_data AS XML).value('(/event/@timestamp)[1]', 'DATETIME2') AS event_timestamp_utc,
    CAST(event_data AS XML).value('(/event/data[@name="specificData"]/value)[1]', 'NVARCHAR(MAX)') AS specificData,
    CAST(event_data AS XML).value('(/event/data[@name="activityId"]/value)[1]', 'UNIQUEIDENTIFIER') AS activityId,
    CAST(event_data AS XML).value('(/event/data[@name="message"]/value)[1]', 'NVARCHAR(MAX)') AS message,
    
    -- Данные из элементов action
    CAST(event_data AS XML).value('(/event/action[@name="event_sequence"]/value)[1]', 'BIGINT') AS event_sequence,
    CAST(event_data AS XML).value('(/event/action[@name="attach_activity_id"]/value)[1]', 'NVARCHAR(50)') AS attach_activity_id,
    
    CAST(event_data AS XML) AS xml -- Полный XML для отладки
FROM #tmp_xe_event_data
WHERE object_name = 'loggerEvent'
ORDER BY event_timestamp_utc

-- Парсинг sp_server_diagnostics_component_result
SELECT 
    -- Данные из элементов data
    CAST(event_data AS XML).value('(/event/@timestamp)[1]', 'DATETIME2') AS event_timestamp_utc,
    CAST(event_data AS XML).value('(/event/data[@name="component"]/value)[1]', 'INT') AS component,
    CAST(event_data AS XML).value('(/event/data[@name="component"]/text)[1]', 'NVARCHAR(100)') AS component_desc,
    CAST(event_data AS XML).value('(/event/data[@name="state"]/value)[1]', 'INT') AS state,
    CAST(event_data AS XML).value('(/event/data[@name="state"]/text)[1]', 'NVARCHAR(50)') AS state_desc,
	CAST(event_data AS XML) AS xml -- Полный XML для отладки
FROM #tmp_xe_event_data
WHERE object_name = 'sp_server_diagnostics_component_result'
ORDER BY event_timestamp_utc, component

-- Парсинг sp_server_diagnostics_component_result с дополнительными полями из system
SELECT 
    -- Данные из элементов data
    CAST(event_data AS XML).value('(/event/@timestamp)[1]', 'DATETIME2') AS event_timestamp_utc,
    CAST(event_data AS XML).value('(/event/data[@name="component"]/value)[1]', 'INT') AS component,
    CAST(event_data AS XML).value('(/event/data[@name="component"]/text)[1]', 'NVARCHAR(100)') AS component_desc,
    CAST(event_data AS XML).value('(/event/data[@name="state"]/value)[1]', 'INT') AS state,
    CAST(event_data AS XML).value('(/event/data[@name="state"]/text)[1]', 'NVARCHAR(50)') AS state_desc,
    
    -- Данные из элемента system внутри data[@name="data"]
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/system/@spinlockBackoffs)[1]', 'BIGINT') AS spinlockBackoffs,
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/system/@sickSpinlockType)[1]', 'NVARCHAR(50)') AS sickSpinlockType,
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/system/@sickSpinlockTypeAfterAv)[1]', 'NVARCHAR(50)') AS sickSpinlockTypeAfterAv,
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/system/@latchWarnings)[1]', 'INT') AS latchWarnings,
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/system/@isAccessViolationOccurred)[1]', 'INT') AS isAccessViolationOccurred,
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/system/@writeAccessViolationCount)[1]', 'INT') AS writeAccessViolationCount,
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/system/@totalDumpRequests)[1]', 'INT') AS totalDumpRequests,
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/system/@intervalDumpRequests)[1]', 'INT') AS intervalDumpRequests,
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/system/@nonYieldingTasksReported)[1]', 'INT') AS nonYieldingTasksReported,
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/system/@pageFaults)[1]', 'BIGINT') AS pageFaults,
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/system/@systemCpuUtilization)[1]', 'INT') AS systemCpuUtilization,
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/system/@sqlCpuUtilization)[1]', 'INT') AS sqlCpuUtilization,
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/system/@BadPagesDetected)[1]', 'INT') AS BadPagesDetected,
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/system/@BadPagesFixed)[1]', 'INT') AS BadPagesFixed,
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/system/@LastBadPageAddress)[1]', 'NVARCHAR(50)') AS LastBadPageAddress,
    
    CAST(event_data AS XML) AS xml -- Полный XML для отладки
FROM #tmp_xe_event_data
WHERE object_name = 'sp_server_diagnostics_component_result'
AND CAST(event_data AS XML).value('(/event/data[@name="component"]/text)[1]', 'NVARCHAR(100)') = 'SYSTEM'
ORDER BY event_timestamp_utc, component

-- Парсинг sp_server_diagnostics_component_result с component_desc = 'RESOURCE'
SELECT 
    -- Данные из элементов data
    CAST(event_data AS XML).value('(/event/@timestamp)[1]', 'DATETIME2') AS event_timestamp_utc,
    CAST(event_data AS XML).value('(/event/data[@name="component"]/value)[1]', 'INT') AS component,
    CAST(event_data AS XML).value('(/event/data[@name="component"]/text)[1]', 'NVARCHAR(100)') AS component_desc,
    CAST(event_data AS XML).value('(/event/data[@name="state"]/value)[1]', 'INT') AS state,
    CAST(event_data AS XML).value('(/event/data[@name="state"]/text)[1]', 'NVARCHAR(50)') AS state_desc,
    
    -- Атрибуты ресурса
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/resource/@lastNotification)[1]', 'NVARCHAR(100)') AS lastNotification,
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/resource/@outOfMemoryExceptions)[1]', 'INT') AS outOfMemoryExceptions,
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/resource/@isAnyPoolOutOfMemory)[1]', 'INT') AS isAnyPoolOutOfMemory,
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/resource/@processOutOfMemoryPeriod)[1]', 'INT') AS processOutOfMemoryPeriod,
    
    -- Данные из Process/System Counts
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/resource/memoryReport[@name="Process/System Counts"]/entry[@description="Available Physical Memory"]/@value)[1]', 'BIGINT') AS available_physical_memory,
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/resource/memoryReport[@name="Process/System Counts"]/entry[@description="Available Virtual Memory"]/@value)[1]', 'BIGINT') AS available_virtual_memory,
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/resource/memoryReport[@name="Process/System Counts"]/entry[@description="Available Paging File"]/@value)[1]', 'BIGINT') AS available_paging_file,
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/resource/memoryReport[@name="Process/System Counts"]/entry[@description="Working Set"]/@value)[1]', 'BIGINT') AS working_set,
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/resource/memoryReport[@name="Process/System Counts"]/entry[@description="Percent of Committed Memory in WS"]/@value)[1]', 'INT') AS percent_committed_memory_in_ws,
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/resource/memoryReport[@name="Process/System Counts"]/entry[@description="Page Faults"]/@value)[1]', 'BIGINT') AS page_faults_counts,
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/resource/memoryReport[@name="Process/System Counts"]/entry[@description="System physical memory high"]/@value)[1]', 'INT') AS system_physical_memory_high,
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/resource/memoryReport[@name="Process/System Counts"]/entry[@description="System physical memory low"]/@value)[1]', 'INT') AS system_physical_memory_low,
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/resource/memoryReport[@name="Process/System Counts"]/entry[@description="Process physical memory low"]/@value)[1]', 'INT') AS process_physical_memory_low,
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/resource/memoryReport[@name="Process/System Counts"]/entry[@description="Process virtual memory low"]/@value)[1]', 'INT') AS process_virtual_memory_low,
    
    -- Данные из Memory Manager
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/resource/memoryReport[@name="Memory Manager"]/entry[@description="VM Reserved"]/@value)[1]', 'BIGINT') AS vm_reserved_kb,
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/resource/memoryReport[@name="Memory Manager"]/entry[@description="VM Committed"]/@value)[1]', 'BIGINT') AS vm_committed_kb,
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/resource/memoryReport[@name="Memory Manager"]/entry[@description="Locked Pages Allocated"]/@value)[1]', 'BIGINT') AS locked_pages_allocated_kb,
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/resource/memoryReport[@name="Memory Manager"]/entry[@description="Large Pages Allocated"]/@value)[1]', 'BIGINT') AS large_pages_allocated_kb,
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/resource/memoryReport[@name="Memory Manager"]/entry[@description="Emergency Memory"]/@value)[1]', 'INT') AS emergency_memory_kb,
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/resource/memoryReport[@name="Memory Manager"]/entry[@description="Emergency Memory In Use"]/@value)[1]', 'INT') AS emergency_memory_in_use_kb,
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/resource/memoryReport[@name="Memory Manager"]/entry[@description="Target Committed"]/@value)[1]', 'BIGINT') AS target_committed_kb,
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/resource/memoryReport[@name="Memory Manager"]/entry[@description="Current Committed"]/@value)[1]', 'BIGINT') AS current_committed_kb,
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/resource/memoryReport[@name="Memory Manager"]/entry[@description="Pages Allocated"]/@value)[1]', 'BIGINT') AS pages_allocated,
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/resource/memoryReport[@name="Memory Manager"]/entry[@description="Pages Reserved"]/@value)[1]', 'BIGINT') AS pages_reserved,
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/resource/memoryReport[@name="Memory Manager"]/entry[@description="Pages Free"]/@value)[1]', 'BIGINT') AS pages_free,
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/resource/memoryReport[@name="Memory Manager"]/entry[@description="Pages In Use"]/@value)[1]', 'BIGINT') AS pages_in_use,
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/resource/memoryReport[@name="Memory Manager"]/entry[@description="Page Alloc Potential"]/@value)[1]', 'BIGINT') AS page_alloc_potential,
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/resource/memoryReport[@name="Memory Manager"]/entry[@description="NUMA Growth Phase"]/@value)[1]', 'INT') AS numa_growth_phase,
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/resource/memoryReport[@name="Memory Manager"]/entry[@description="Last OOM Factor"]/@value)[1]', 'INT') AS last_oom_factor,
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/resource/memoryReport[@name="Memory Manager"]/entry[@description="Last OS Error"]/@value)[1]', 'INT') AS last_os_error,
    
    CAST(event_data AS XML) AS xml -- Полный XML для отладки
FROM #tmp_xe_event_data
WHERE object_name = 'sp_server_diagnostics_component_result'
AND CAST(event_data AS XML).value('(/event/data[@name="component"]/text)[1]', 'NVARCHAR(100)') = 'RESOURCE' -- Фильтр по component_desc
ORDER BY event_timestamp_utc, component

-- Парсинг sp_server_diagnostics_component_result с component_desc = 'QUERY_PROCESSING'
SELECT 
    -- Данные из элементов data
    CAST(event_data AS XML).value('(/event/@timestamp)[1]', 'DATETIME2') AS event_timestamp_utc,
    CAST(event_data AS XML).value('(/event/data[@name="component"]/value)[1]', 'INT') AS component,
    CAST(event_data AS XML).value('(/event/data[@name="component"]/text)[1]', 'NVARCHAR(100)') AS component_desc,
    CAST(event_data AS XML).value('(/event/data[@name="state"]/value)[1]', 'INT') AS state,
    CAST(event_data AS XML).value('(/event/data[@name="state"]/text)[1]', 'NVARCHAR(50)') AS state_desc,
    
    -- Атрибуты queryProcessing
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/queryProcessing/@maxWorkers)[1]', 'INT') AS maxWorkers,
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/queryProcessing/@workersCreated)[1]', 'INT') AS workersCreated,
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/queryProcessing/@workersIdle)[1]', 'INT') AS workersIdle,
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/queryProcessing/@tasksCompletedWithinInterval)[1]', 'INT') AS tasksCompletedWithinInterval,
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/queryProcessing/@pendingTasks)[1]', 'INT') AS pendingTasks,
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/queryProcessing/@oldestPendingTaskWaitingTime)[1]', 'INT') AS oldestPendingTaskWaitingTime,
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/queryProcessing/@hasUnresolvableDeadlockOccurred)[1]', 'INT') AS hasUnresolvableDeadlockOccurred,
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/queryProcessing/@hasDeadlockedSchedulersOccurred)[1]', 'INT') AS hasDeadlockedSchedulersOccurred,
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/queryProcessing/@trackingNonYieldingScheduler)[1]', 'NVARCHAR(50)') AS trackingNonYieldingScheduler,
    
    CAST(event_data AS XML) AS xml -- Полный XML для отладки
FROM #tmp_xe_event_data
WHERE object_name = 'sp_server_diagnostics_component_result'
AND CAST(event_data AS XML).value('(/event/data[@name="component"]/text)[1]', 'NVARCHAR(100)') = 'QUERY_PROCESSING' -- Фильтр по component_desc
ORDER BY event_timestamp_utc, component

-- Парсинг sp_server_diagnostics_component_result с component_desc = 'IO_SUBSYSTEM'
SELECT 
    -- Данные из элементов data
    CAST(event_data AS XML).value('(/event/@timestamp)[1]', 'DATETIME2') AS event_timestamp_utc,
    CAST(event_data AS XML).value('(/event/data[@name="component"]/value)[1]', 'INT') AS component,
    CAST(event_data AS XML).value('(/event/data[@name="component"]/text)[1]', 'NVARCHAR(100)') AS component_desc,
    CAST(event_data AS XML).value('(/event/data[@name="state"]/value)[1]', 'INT') AS state,
    CAST(event_data AS XML).value('(/event/data[@name="state"]/text)[1]', 'NVARCHAR(50)') AS state_desc,
    
    -- Атрибуты ioSubsystem
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/ioSubsystem/@ioLatchTimeouts)[1]', 'INT') AS ioLatchTimeouts,
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/ioSubsystem/@intervalLongIos)[1]', 'INT') AS intervalLongIos,
    CAST(event_data AS XML).value('(/event/data[@name="data"]/value/ioSubsystem/@totalLongIos)[1]', 'INT') AS totalLongIos,
    
    CAST(event_data AS XML) AS xml -- Полный XML для отладки
FROM #tmp_xe_event_data
WHERE object_name = 'sp_server_diagnostics_component_result'
AND CAST(event_data AS XML).value('(/event/data[@name="component"]/text)[1]', 'NVARCHAR(100)') = 'IO_SUBSYSTEM' -- Фильтр по component_desc
ORDER BY event_timestamp_utc, component
