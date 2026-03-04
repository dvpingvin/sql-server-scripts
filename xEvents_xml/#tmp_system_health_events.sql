-- Создаем временную таблицу для хранения результатов
DROP TABLE IF EXISTS #tmp_system_health_events;
CREATE TABLE #tmp_system_health_events (
    [source_name] NVARCHAR(20),
    [current_time] DATETIME,
    [event_name] NVARCHAR(100),
    [event_package] NVARCHAR(50),
    [event_timestamp] DATETIME2,
    [event_data] XML
);

-- Вставляем в #tmp_system_health_events данные из ring_buffer
INSERT INTO #tmp_system_health_events ([source_name], [current_time], [event_name], [event_package], [event_timestamp], [event_data])
SELECT TOP 10
    'ring_buffer' AS [source_name],
    SYSDATETIME() AS [current_time],
    event_data.value('@name', 'NVARCHAR(100)') AS event_name,
    event_data.value('@package', 'NVARCHAR(50)') AS event_package,
    event_data.value('@timestamp', 'DATETIME2') AS event_timestamp,
    event_data.query('.') AS event_xml
FROM (
    SELECT CAST(target_data AS XML) AS ring_buffer_xml
    FROM sys.dm_xe_session_targets st
    JOIN sys.dm_xe_sessions s ON s.address = st.event_session_address
    WHERE s.name = 'system_health' AND st.target_name = 'ring_buffer'
) rb
CROSS APPLY rb.ring_buffer_xml.nodes('/RingBufferTarget/event') AS t(event_data);

-- Получаем пути к файлам system_health правильно
DECLARE @files TABLE (file_path NVARCHAR(1000));

INSERT INTO @files (file_path)
SELECT 
    tx.target_xml.value('(EventFileTarget/File/@name)[1]', 'NVARCHAR(1000)') AS file_path
FROM (
    SELECT CAST(st.target_data AS XML) AS target_xml
    FROM sys.dm_xe_session_targets st
    JOIN sys.dm_xe_sessions s ON s.address = st.event_session_address
    WHERE s.name = 'system_health' 
      AND st.target_name = 'event_file'
) AS tx;

-- Вставляем в #tmp_system_health_events из файлов system_health
INSERT INTO #tmp_system_health_events ([source_name], [current_time], [event_name], [event_package], [event_timestamp], [event_data])
SELECT TOP 10
    'event_file' AS [source_name],
    SYSDATETIME() AS [current_time],
    e.event_data.value('@name', 'NVARCHAR(100)') AS event_name,
    e.event_data.value('@package', 'NVARCHAR(50)') AS event_package,
    e.event_data.value('@timestamp', 'DATETIME2') AS event_timestamp,
    e.event_data.query('.') AS event_data
FROM @files f
CROSS APPLY sys.fn_xe_file_target_read_file(f.file_path, NULL, NULL, NULL) AS ft
CROSS APPLY (SELECT CAST(ft.event_data AS XML) AS event_xml) AS ex
CROSS APPLY ex.event_xml.nodes('/event') AS e(event_data)
WHERE e.event_data.value('@name', 'NVARCHAR(100)') IN (
    'xml_deadlock_report',                                   -- Отчеты о дедлоках (КРИТИЧНО)
    'sp_server_diagnostics_component_result'                 -- Результаты диагностики сервера (ВАЖНО)
    --'resource_monitor_ring_buffer_recorded',                 -- Мониторинг памяти (ОЧЕНЬ ВАЖНО)
    --'memory_broker_ring_buffer_recorded',                    -- Распределитель памяти (ОЧЕНЬ ВАЖНО)
    --'spinlock_backoff',                                      -- Ожидания на spinlock (ВАЖНО)
)

/*
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
ORDER BY e.event_data.value('@timestamp', 'DATETIME2') DESC;

select * from #tmp_system_health_events
