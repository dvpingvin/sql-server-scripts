DROP TABLE IF EXISTS #system_health_ring_buffer;

-- Чтение из кольцевого буфера system_health
SELECT 
    CAST(target_data AS XML) AS event_xml
INTO #system_health_ring_buffer
FROM sys.dm_xe_session_targets st
JOIN sys.dm_xe_sessions s ON s.address = st.event_session_address
WHERE s.name = 'system_health' 
  AND st.target_name = 'ring_buffer';

-- Парсинг событий из кольцевого буфера
SELECT 
    GETDATE() AS create_time,
    'events' AS component_name,
    event.value('@name', 'NVARCHAR(100)') AS event_name,
    event.value('@package', 'NVARCHAR(50)') AS event_package,
    event.value('@timestamp', 'DATETIME2') AS event_timestamp,
    event.query('.') AS event_data
FROM #system_health_ring_buffer
CROSS APPLY event_xml.nodes('/RingBufferTarget/event') AS t(event);

--DROP TABLE IF EXISTS #system_health_ring_buffer;
