-- Смотрим, что вообще есть
SELECT s.name, st.target_name, /* s.total_bytes_generated / 1048576 AS total_mb_generated, st.bytes_written / 1048576 AS mb_written, s.total_target_memory / 1048576 AS total_target_mb, */
CAST(st.target_data AS XML).value('(EventFileTarget/File/@name)[1]', 'NVARCHAR(1000)') AS target_xml_path,
CAST(st.target_data AS XML) AS target_xml
FROM sys.dm_xe_sessions s
RIGHT JOIN sys.dm_xe_session_targets st ON s.address = st.event_session_address

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

-- Парсинг error_reported
SELECT 
    -- Данные из элементов data
    CAST(event_data AS XML).value('(/event/@timestamp)[1]', 'DATETIME2') AS event_timestamp_utc,
    CAST(event_data AS XML).value('(/event/data[@name="error_number"]/value)[1]', 'INT') AS error_number,
    CAST(event_data AS XML).value('(/event/data[@name="severity"]/value)[1]', 'INT') AS severity,
    CAST(event_data AS XML).value('(/event/data[@name="state"]/value)[1]', 'INT') AS state,
    CAST(event_data AS XML).value('(/event/data[@name="user_defined"]/value)[1]', 'BIT') AS user_defined,
    CAST(event_data AS XML).value('(/event/data[@name="category"]/value)[1]', 'INT') AS category,
    CAST(event_data AS XML).value('(/event/data[@name="category"]/text)[1]', 'NVARCHAR(50)') AS category_desc,
    CAST(event_data AS XML).value('(/event/data[@name="destination"]/value)[1]', 'NVARCHAR(50)') AS destination,
    CAST(event_data AS XML).value('(/event/data[@name="destination"]/text)[1]', 'NVARCHAR(50)') AS destination_desc,
    CAST(event_data AS XML).value('(/event/data[@name="is_intercepted"]/value)[1]', 'BIT') AS is_intercepted,
    CAST(event_data AS XML).value('(/event/data[@name="message"]/value)[1]', 'NVARCHAR(MAX)') AS message,
    CAST(event_data AS XML) AS xml -- Полный XML для отладки
FROM #tmp_xe_event_data
WHERE object_name = 'error_reported'
ORDER BY event_timestamp_utc

-- Парсинг auto_stats
SELECT 
    -- Данные из элементов data
    CAST(event_data AS XML).value('(/event/@timestamp)[1]', 'DATETIME2') AS event_timestamp_utc,
    CAST(event_data AS XML).value('(/event/data[@name="database_id"]/value)[1]', 'INT') AS database_id,
    CAST(event_data AS XML).value('(/event/data[@name="object_id"]/value)[1]', 'BIGINT') AS object_id,
    CAST(event_data AS XML).value('(/event/data[@name="index_id"]/value)[1]', 'INT') AS index_id,
    CAST(event_data AS XML).value('(/event/data[@name="job_id"]/value)[1]', 'INT') AS job_id,
    CAST(event_data AS XML).value('(/event/data[@name="job_type"]/value)[1]', 'INT') AS job_type,
    CAST(event_data AS XML).value('(/event/data[@name="job_type"]/text)[1]', 'NVARCHAR(50)') AS job_type_desc,
    CAST(event_data AS XML).value('(/event/data[@name="status"]/value)[1]', 'INT') AS status,
    CAST(event_data AS XML).value('(/event/data[@name="status"]/text)[1]', 'NVARCHAR(100)') AS status_desc,
    CAST(event_data AS XML).value('(/event/data[@name="incremental"]/value)[1]', 'BIT') AS incremental,
    CAST(event_data AS XML).value('(/event/data[@name="async"]/value)[1]', 'BIT') AS async,
    CAST(event_data AS XML).value('(/event/data[@name="max_dop"]/value)[1]', 'INT') AS max_dop,
    CAST(event_data AS XML).value('(/event/data[@name="sample_percentage"]/value)[1]', 'BIGINT') AS sample_percentage,
    CAST(event_data AS XML).value('(/event/data[@name="duration"]/value)[1]', 'BIGINT') AS duration,
    CAST(event_data AS XML).value('(/event/data[@name="retries"]/value)[1]', 'INT') AS retries,
    CAST(event_data AS XML).value('(/event/data[@name="success"]/value)[1]', 'BIT') AS success,
    CAST(event_data AS XML).value('(/event/data[@name="last_error"]/value)[1]', 'INT') AS last_error,
    CAST(event_data AS XML).value('(/event/data[@name="count"]/value)[1]', 'INT') AS count,
    CAST(event_data AS XML).value('(/event/data[@name="statistics_list"]/value)[1]', 'NVARCHAR(MAX)') AS statistics_list,
    CAST(event_data AS XML).value('(/event/data[@name="database_name"]/value)[1]', 'NVARCHAR(128)') AS database_name,
    CAST(event_data AS XML) AS xml -- Полный XML для отладки
FROM #tmp_xe_event_data
WHERE object_name = 'auto_stats'
ORDER BY event_timestamp_utc


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


-- Парсинг tx_commit_abort_stats
SELECT 
    -- Данные из элементов data
    CAST(event_data AS XML).value('(/event/@timestamp)[1]', 'DATETIME2') AS event_timestamp_utc,
    CAST(event_data AS XML).value('(/event/data[@name="database_id"]/value)[1]', 'INT') AS database_id,
    CAST(event_data AS XML).value('(/event/data[@name="is_adr_enabled"]/value)[1]', 'BIT') AS is_adr_enabled,
    CAST(event_data AS XML).value('(/event/data[@name="is_adr_disabled_by_design"]/value)[1]', 'BIT') AS is_adr_disabled_by_design,
    CAST(event_data AS XML).value('(/event/data[@name="is_adr_disabled_by_traceflag"]/value)[1]', 'BIT') AS is_adr_disabled_by_traceflag,
    CAST(event_data AS XML).value('(/event/data[@name="tx_non_adr_count"]/value)[1]', 'BIGINT') AS tx_non_adr_count,
    CAST(event_data AS XML).value('(/event/data[@name="tx_commit_count"]/value)[1]', 'BIGINT') AS tx_commit_count,
    CAST(event_data AS XML).value('(/event/data[@name="short_tx_rollback_count"]/value)[1]', 'BIGINT') AS short_tx_rollback_count,
    CAST(event_data AS XML).value('(/event/data[@name="long_tx_rollback_count"]/value)[1]', 'BIGINT') AS long_tx_rollback_count,
    CAST(event_data AS XML).value('(/event/data[@name="adr_tx_rollback_count"]/value)[1]', 'BIGINT') AS adr_tx_rollback_count,
    CAST(event_data AS XML).value('(/event/data[@name="nest_aborted_count"]/value)[1]', 'BIGINT') AS nest_aborted_count,
    CAST(event_data AS XML).value('(/event/data[@name="savepoint_aborted_count"]/value)[1]', 'BIGINT') AS savepoint_aborted_count,
    CAST(event_data AS XML).value('(/event/data[@name="nest_id_from_off_row_count"]/value)[1]', 'BIGINT') AS nest_id_from_off_row_count,
    CAST(event_data AS XML).value('(/event/data[@name="lr_btree_count"]/value)[1]', 'BIGINT') AS lr_btree_count,
    CAST(event_data AS XML).value('(/event/data[@name="lr_heap_count"]/value)[1]', 'BIGINT') AS lr_heap_count,
    CAST(event_data AS XML).value('(/event/data[@name="lr_blob_count"]/value)[1]', 'BIGINT') AS lr_blob_count,
    CAST(event_data AS XML).value('(/event/data[@name="updates_on_top_aborted_rows_count"]/value)[1]', 'BIGINT') AS updates_on_top_aborted_rows_count,
    CAST(event_data AS XML).value('(/event/data[@name="tx_rollback_count"]/value)[1]', 'BIGINT') AS tx_rollback_count,
    CAST(event_data AS XML).value('(/event/data[@name="current_abort_count"]/value)[1]', 'INT') AS current_abort_count,
    CAST(event_data AS XML).value('(/event/data[@name="persisted_version_store_kb"]/value)[1]', 'BIGINT') AS persisted_version_store_kb,
    CAST(event_data AS XML).value('(/event/data[@name="tx_started_long_time_ago"]/value)[1]', 'BIGINT') AS tx_started_long_time_ago,
    CAST(event_data AS XML).value('(/event/data[@name="multiple_version_from_nest_tran"]/value)[1]', 'BIGINT') AS multiple_version_from_nest_tran,
    CAST(event_data AS XML).value('(/event/data[@name="is_elastic_pool_db"]/value)[1]', 'BIGINT') AS is_elastic_pool_db,
    CAST(event_data AS XML).value('(/event/data[@name="is_mtvc_enabled"]/value)[1]', 'BIGINT') AS is_mtvc_enabled,
    CAST(event_data AS XML).value('(/event/data[@name="do_only_lr_count"]/value)[1]', 'BIGINT') AS do_only_lr_count,
    CAST(event_data AS XML).value('(/event/data[@name="is_mtvc_within_db_enabled"]/value)[1]', 'BIGINT') AS is_mtvc_within_db_enabled,
    CAST(event_data AS XML) AS xml -- Полный XML для отладки
FROM #tmp_xe_event_data
WHERE object_name = 'tx_commit_abort_stats'
ORDER BY event_timestamp_utc

-- Парсинг login_protocol_count
SELECT 
    -- Данные из элементов data
    CAST(event_data AS XML).value('(/event/@timestamp)[1]', 'DATETIME2') AS event_timestamp_utc,
    CAST(event_data AS XML).value('(/event/data[@name="protocol"]/value)[1]', 'NVARCHAR(100)') AS protocol,
    CAST(event_data AS XML) AS xml -- Полный XML для отладки
FROM #tmp_xe_event_data
WHERE object_name = 'login_protocol_count'
ORDER BY event_timestamp_utc

-- Парсинг cardinality_estimation_version_usage
SELECT 
    -- Данные из элементов data
    CAST(event_data AS XML).value('(/event/@timestamp)[1]', 'DATETIME2') AS event_timestamp_utc,
    CAST(event_data AS XML).value('(/event/data[@name="default_ce_count"]/value)[1]', 'INT') AS default_ce_count,
    CAST(event_data AS XML).value('(/event/data[@name="legacy_ce_from_queryhint_count"]/value)[1]', 'INT') AS legacy_ce_from_queryhint_count,
    CAST(event_data AS XML).value('(/event/data[@name="default_ce_from_queryhint_count"]/value)[1]', 'INT') AS default_ce_from_queryhint_count,
    CAST(event_data AS XML).value('(/event/data[@name="conflict_in_ce_request_count"]/value)[1]', 'INT') AS conflict_in_ce_request_count,
    CAST(event_data AS XML).value('(/event/data[@name="legacy_ce_from_dbscopedconfig_count"]/value)[1]', 'INT') AS legacy_ce_from_dbscopedconfig_count,
    CAST(event_data AS XML).value('(/event/data[@name="legacy_ce_from_global_tf_count"]/value)[1]', 'INT') AS legacy_ce_from_global_tf_count,
    CAST(event_data AS XML).value('(/event/data[@name="legacy_ce_from_session_tf_count"]/value)[1]', 'INT') AS legacy_ce_from_session_tf_count,
    CAST(event_data AS XML).value('(/event/data[@name="ce_atleast120_from_global_tf_count"]/value)[1]', 'INT') AS ce_atleast120_from_global_tf_count,
    CAST(event_data AS XML).value('(/event/data[@name="ce_atleast120_from_session_tf_count"]/value)[1]', 'INT') AS ce_atleast120_from_session_tf_count,
    CAST(event_data AS XML) AS xml -- Полный XML для отладки
FROM #tmp_xe_event_data
WHERE object_name = 'cardinality_estimation_version_usage'
ORDER BY event_timestamp_utc

-- Парсинг query_store_db_diagnostics
SELECT 
    -- Данные из элементов data
    CAST(event_data AS XML).value('(/event/@timestamp)[1]', 'DATETIME2') AS event_timestamp_utc,
    CAST(event_data AS XML).value('(/event/data[@name="database_id"]/value)[1]', 'INT') AS database_id,
    CAST(event_data AS XML).value('(/event/data[@name="query_count"]/value)[1]', 'INT') AS query_count,
    CAST(event_data AS XML).value('(/event/data[@name="queries_used_last_hour"]/value)[1]', 'INT') AS queries_used_last_hour,
    CAST(event_data AS XML).value('(/event/data[@name="queries_used_last_day"]/value)[1]', 'INT') AS queries_used_last_day,
    CAST(event_data AS XML).value('(/event/data[@name="undecided_query_count"]/value)[1]', 'INT') AS undecided_query_count,
    CAST(event_data AS XML).value('(/event/data[@name="query_text_count"]/value)[1]', 'INT') AS query_text_count,
    CAST(event_data AS XML).value('(/event/data[@name="plan_count"]/value)[1]', 'INT') AS plan_count,
    CAST(event_data AS XML).value('(/event/data[@name="plans_used_last_hour"]/value)[1]', 'INT') AS plans_used_last_hour,
    CAST(event_data AS XML).value('(/event/data[@name="plans_used_last_day"]/value)[1]', 'INT') AS plans_used_last_day,
    CAST(event_data AS XML).value('(/event/data[@name="context_settings_memory_usage_kb"]/value)[1]', 'BIGINT') AS context_settings_memory_usage_kb,
    CAST(event_data AS XML).value('(/event/data[@name="runtime_stats_memory_usage_kb"]/value)[1]', 'BIGINT') AS runtime_stats_memory_usage_kb,
    CAST(event_data AS XML).value('(/event/data[@name="pending_persistance_memory_usage_kb"]/value)[1]', 'BIGINT') AS pending_persistance_memory_usage_kb,
    CAST(event_data AS XML).value('(/event/data[@name="db_state_actual"]/value)[1]', 'INT') AS db_state_actual,
    CAST(event_data AS XML).value('(/event/data[@name="db_state_desired"]/value)[1]', 'INT') AS db_state_desired,
    CAST(event_data AS XML).value('(/event/data[@name="query_store_read_only_reason"]/value)[1]', 'INT') AS query_store_read_only_reason,
    CAST(event_data AS XML).value('(/event/data[@name="flush_interval_seconds"]/value)[1]', 'INT') AS flush_interval_seconds,
    CAST(event_data AS XML).value('(/event/data[@name="interval_length_minutes"]/value)[1]', 'INT') AS interval_length_minutes,
    CAST(event_data AS XML).value('(/event/data[@name="max_size_mb"]/value)[1]', 'INT') AS max_size_mb,
    CAST(event_data AS XML).value('(/event/data[@name="stale_query_threshold_days"]/value)[1]', 'INT') AS stale_query_threshold_days,
    CAST(event_data AS XML).value('(/event/data[@name="max_plans_per_query"]/value)[1]', 'INT') AS max_plans_per_query,
    CAST(event_data AS XML).value('(/event/data[@name="current_stmt_hash_map_size_kb"]/value)[1]', 'BIGINT') AS current_stmt_hash_map_size_kb,
    CAST(event_data AS XML).value('(/event/data[@name="max_stmt_hash_map_size_kb"]/value)[1]', 'BIGINT') AS max_stmt_hash_map_size_kb,
    CAST(event_data AS XML).value('(/event/data[@name="current_buffered_items_size_kb"]/value)[1]', 'BIGINT') AS current_buffered_items_size_kb,
    CAST(event_data AS XML).value('(/event/data[@name="max_buffered_items_size_kb"]/value)[1]', 'BIGINT') AS max_buffered_items_size_kb,
    CAST(event_data AS XML).value('(/event/data[@name="max_memory_available_kb"]/value)[1]', 'BIGINT') AS max_memory_available_kb,
    CAST(event_data AS XML).value('(/event/data[@name="undecided_queries_window_duration_minutes"]/value)[1]', 'INT') AS undecided_queries_window_duration_minutes,
    CAST(event_data AS XML).value('(/event/data[@name="capture_policy_mode"]/value)[1]', 'INT') AS capture_policy_mode,
    CAST(event_data AS XML).value('(/event/data[@name="capture_policy_mode"]/text)[1]', 'NVARCHAR(50)') AS capture_policy_mode_desc,
    CAST(event_data AS XML).value('(/event/data[@name="capture_policy_execution_count"]/value)[1]', 'INT') AS capture_policy_execution_count,
    CAST(event_data AS XML).value('(/event/data[@name="capture_policy_total_compile_cpu_ms"]/value)[1]', 'BIGINT') AS capture_policy_total_compile_cpu_ms,
    CAST(event_data AS XML).value('(/event/data[@name="capture_policy_total_execution_cpu_ms"]/value)[1]', 'BIGINT') AS capture_policy_total_execution_cpu_ms,
    CAST(event_data AS XML).value('(/event/data[@name="capture_policy_stale_threshold_hours"]/value)[1]', 'INT') AS capture_policy_stale_threshold_hours,
    CAST(event_data AS XML).value('(/event/data[@name="size_based_cleanup_mode"]/value)[1]', 'INT') AS size_based_cleanup_mode,
    CAST(event_data AS XML).value('(/event/data[@name="size_based_cleanup_mode"]/text)[1]', 'NVARCHAR(50)') AS size_based_cleanup_mode_desc,
    CAST(event_data AS XML).value('(/event/data[@name="size_based_cleanup_percent_trigger"]/value)[1]', 'INT') AS size_based_cleanup_percent_trigger,
    CAST(event_data AS XML).value('(/event/data[@name="size_based_cleanup_percent_target"]/value)[1]', 'INT') AS size_based_cleanup_percent_target,
    CAST(event_data AS XML).value('(/event/data[@name="wait_stats_capture_mode"]/value)[1]', 'INT') AS wait_stats_capture_mode,
    CAST(event_data AS XML).value('(/event/data[@name="wait_stats_capture_mode"]/text)[1]', 'NVARCHAR(50)') AS wait_stats_capture_mode_desc,
    CAST(event_data AS XML).value('(/event/data[@name="fast_path_optimization_mode"]/value)[1]', 'INT') AS fast_path_optimization_mode,
    CAST(event_data AS XML).value('(/event/data[@name="fast_path_optimization_mode"]/text)[1]', 'NVARCHAR(50)') AS fast_path_optimization_mode_desc,
    CAST(event_data AS XML).value('(/event/data[@name="pending_message_count"]/value)[1]', 'BIGINT') AS pending_message_count,
    CAST(event_data AS XML).value('(/event/data[@name="messaging_memory_used_mb"]/value)[1]', 'BIGINT') AS messaging_memory_used_mb,
    CAST(event_data AS XML).value('(/event/data[@name="messaging_discarded_message_count"]/value)[1]', 'BIGINT') AS messaging_discarded_message_count,
    CAST(event_data AS XML).value('(/event/data[@name="messaging_internal_max_threshold"]/value)[1]', 'BIGINT') AS messaging_internal_max_threshold,
    CAST(event_data AS XML) AS xml -- Полный XML для отладки
FROM #tmp_xe_event_data
WHERE object_name = 'query_store_db_diagnostics'
ORDER BY event_timestamp_utc

-- Парсинг server_memory_change
SELECT 
    -- Данные из элементов data
    CAST(event_data AS XML).value('(/event/@timestamp)[1]', 'DATETIME2') AS event_timestamp_utc,
    CAST(event_data AS XML).value('(/event/data[@name="memory_change"]/value)[1]', 'INT') AS memory_change,
    CAST(event_data AS XML).value('(/event/data[@name="memory_change"]/text)[1]', 'NVARCHAR(50)') AS memory_change_desc,
    CAST(event_data AS XML).value('(/event/data[@name="new_memory_size_mb"]/value)[1]', 'INT') AS new_memory_size_mb,
    CAST(event_data AS XML) AS xml -- Полный XML для отладки
FROM #tmp_xe_event_data
WHERE object_name = 'server_memory_change'
ORDER BY event_timestamp_utc

-- Парсинг sequence_function_used
SELECT 
    -- Данные из элементов data
    CAST(event_data AS XML).value('(/event/@timestamp)[1]', 'DATETIME2') AS event_timestamp_utc,
    CAST(event_data AS XML).value('(/event/data[@name="execution_details"]/value)[1]', 'NVARCHAR(100)') AS execution_details,
    -- Данные из элементов action
    CAST(event_data AS XML).value('(/event/action[@name="database_id"]/value)[1]', 'INT') AS database_id,
    CAST(event_data AS XML) AS xml -- Полный XML для отладки
FROM #tmp_xe_event_data
WHERE object_name = 'sequence_function_used'
ORDER BY event_timestamp_utc


-- Парсинг recovery_checkpoint_stats
SELECT 
    -- Данные из элементов data
    CAST(event_data AS XML).value('(/event/@timestamp)[1]', 'DATETIME2') AS event_timestamp_utc,
    CAST(event_data AS XML).value('(/event/data[@name="database_id"]/value)[1]', 'INT') AS database_id,
    CAST(event_data AS XML).value('(/event/data[@name="dirty_page_mgr_config"]/value)[1]', 'INT') AS dirty_page_mgr_config,
    CAST(event_data AS XML).value('(/event/data[@name="target_recovery_time_sec"]/value)[1]', 'INT') AS target_recovery_time_sec,
    CAST(event_data AS XML).value('(/event/data[@name="dirty_page_count"]/value)[1]', 'BIGINT') AS dirty_page_count,
    CAST(event_data AS XML).value('(/event/data[@name="dirty_page_read_time_ms"]/value)[1]', 'BIGINT') AS dirty_page_read_time_ms,
    CAST(event_data AS XML).value('(/event/data[@name="dirty_page_target_time_ms"]/value)[1]', 'BIGINT') AS dirty_page_target_time_ms,
    CAST(event_data AS XML).value('(/event/data[@name="dplist_lock_backoffs_per_min"]/value)[1]', 'BIGINT') AS dplist_lock_backoffs_per_min,
    CAST(event_data AS XML).value('(/event/data[@name="dplist_lock_collisions_per_min"]/value)[1]', 'BIGINT') AS dplist_lock_collisions_per_min,
    CAST(event_data AS XML).value('(/event/data[@name="dplist_lock_spins_per_collision"]/value)[1]', 'BIGINT') AS dplist_lock_spins_per_collision,
    CAST(event_data AS XML).value('(/event/data[@name="is_acceptlog_mode"]/value)[1]', 'BIT') AS is_acceptlog_mode,
    CAST(event_data AS XML).value('(/event/data[@name="recovery_data_read_time_estimate_ms"]/value)[1]', 'BIGINT') AS recovery_data_read_time_estimate_ms,
    CAST(event_data AS XML).value('(/event/data[@name="recovery_log_bytes"]/value)[1]', 'BIGINT') AS recovery_log_bytes,
    CAST(event_data AS XML).value('(/event/data[@name="recovery_log_read_time_estimate_ms"]/value)[1]', 'BIGINT') AS recovery_log_read_time_estimate_ms,
    CAST(event_data AS XML).value('(/event/data[@name="recovery_log_target_time_ms"]/value)[1]', 'BIGINT') AS recovery_log_target_time_ms,
    CAST(event_data AS XML).value('(/event/data[@name="recovery_time_estimate_sec"]/value)[1]', 'BIGINT') AS recovery_time_estimate_sec,
    CAST(event_data AS XML).value('(/event/data[@name="recovery_writer_group_queued_ios"]/value)[1]', 'BIGINT') AS recovery_writer_group_queued_ios,
    CAST(event_data AS XML).value('(/event/data[@name="current_lsn"]/value)[1]', 'NVARCHAR(50)') AS current_lsn,
    CAST(event_data AS XML).value('(/event/data[@name="current_oldest_page_lsn"]/value)[1]', 'NVARCHAR(50)') AS current_oldest_page_lsn,
    CAST(event_data AS XML).value('(/event/data[@name="database_name"]/value)[1]', 'NVARCHAR(128)') AS database_name,
    CAST(event_data AS XML) AS xml -- Полный XML для отладки
FROM #tmp_xe_event_data
WHERE object_name = 'recovery_checkpoint_stats'
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
