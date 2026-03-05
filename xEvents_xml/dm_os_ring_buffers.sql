-- сохраняем кольцевые буфферы во временную таблицу, т.к. они перезатираются
SELECT 
    ROW_NUMBER() OVER (ORDER BY rb.timestamp DESC) AS [Record id],
    rb.ring_buffer_type AS [type],
	CAST(record AS xml) AS [xml],
    DATEADD(second, (rb.timestamp - si.ms_ticks)/1000, GETDATE()) AS [time]
INTO tmp_rb_record_data
FROM sys.dm_os_ring_buffers rb
CROSS JOIN sys.dm_os_sys_info si
ORDER BY rb.timestamp DESC;

-- запрос для парсинга XML типа RING_BUFFER_MEMORY_BROKER_CLERKS
SELECT 
    ROW_NUMBER() OVER (ORDER BY rb.timestamp DESC) AS [Record id],
    rb.ring_buffer_type AS [type],
    DATEADD(second, (rb.timestamp - si.ms_ticks)/1000, GETDATE()) AS [time],
    
    -- Распарсенные поля из XML
    record_xml.value('(./Record/@id)[1]', 'INT') AS [Record_xml_id],
    
    -- Поля из MemoryBrokerClerk
    record_xml.value('(./Record/MemoryBrokerClerk/Name)[1]', 'VARCHAR(100)') AS [Clerk_Name],
    record_xml.value('(./Record/MemoryBrokerClerk/TotalPages)[1]', 'BIGINT') AS [TotalPages],
    record_xml.value('(./Record/MemoryBrokerClerk/SimulatedPages)[1]', 'BIGINT') AS [SimulatedPages],
    record_xml.value('(./Record/MemoryBrokerClerk/SimulationBenefit)[1]', 'DECIMAL(20,10)') AS [SimulationBenefit],
    record_xml.value('(./Record/MemoryBrokerClerk/InternalBenefit)[1]', 'DECIMAL(20,10)') AS [InternalBenefit],
    record_xml.value('(./Record/MemoryBrokerClerk/ExternalBenefit)[1]', 'DECIMAL(20,10)') AS [ExternalBenefit],
    record_xml.value('(./Record/MemoryBrokerClerk/ValueOfMemory)[1]', 'DECIMAL(20,10)') AS [ValueOfMemory],
    record_xml.value('(./Record/MemoryBrokerClerk/PeriodicFreedPages)[1]', 'BIGINT') AS [PeriodicFreedPages],
    record_xml.value('(./Record/MemoryBrokerClerk/InternalFreedPages)[1]', 'BIGINT') AS [InternalFreedPages],
    
    -- Вычисляемые поля
    record_xml.value('(./Record/MemoryBrokerClerk/TotalPages)[1]', 'BIGINT') * 8 / 1024.0 AS [TotalMemory_MB]
    
FROM sys.dm_os_ring_buffers rb
CROSS JOIN sys.dm_os_sys_info si
CROSS APPLY (SELECT CAST(rb.record AS XML) AS record_xml) AS x
WHERE rb.ring_buffer_type = 'RING_BUFFER_MEMORY_BROKER_CLERKS'
ORDER BY rb.timestamp, [Clerk_Name], [Record_xml_id];

-- запрос для парсинга XML типа RING_BUFFER_RESOURCE_MONITOR
SELECT 
    ROW_NUMBER() OVER (ORDER BY rb.timestamp DESC) AS [Record id],
    rb.ring_buffer_type AS [type],
    DATEADD(second, (rb.timestamp - si.ms_ticks)/1000, GETDATE()) AS [time],
    
    -- Распарсенные поля из XML
    record_xml.value('(./Record/@id)[1]', 'INT') AS [Record_xml_id],
    
    -- ResourceMonitor
    record_xml.value('(./Record/ResourceMonitor/Notification)[1]', 'VARCHAR(50)') AS [Notification],
    record_xml.value('(./Record/ResourceMonitor/IndicatorsProcess)[1]', 'INT') AS [IndicatorsProcess],
    record_xml.value('(./Record/ResourceMonitor/IndicatorsSystem)[1]', 'INT') AS [IndicatorsSystem],
    record_xml.value('(./Record/ResourceMonitor/IndicatorsPool)[1]', 'INT') AS [IndicatorsPool],
    record_xml.value('(./Record/ResourceMonitor/NodeId)[1]', 'INT') AS [NodeId],
    
    -- Effect записи
    record_xml.value('(./Record/ResourceMonitor/Effect[@type="APPLY_LOWPM"]/text())[1]', 'BIGINT') AS [APPLY_LOWPM_Value],
    record_xml.value('(./Record/ResourceMonitor/Effect[@type="APPLY_LOWPM"]/@state)[1]', 'VARCHAR(50)') AS [APPLY_LOWPM_State],
    
    record_xml.value('(./Record/ResourceMonitor/Effect[@type="APPLY_HIGHPM"]/text())[1]', 'BIGINT') AS [APPLY_HIGHPM_Value],
    record_xml.value('(./Record/ResourceMonitor/Effect[@type="APPLY_HIGHPM"]/@state)[1]', 'VARCHAR(50)') AS [APPLY_HIGHPM_State],
    
    record_xml.value('(./Record/ResourceMonitor/Effect[@type="REVERT_HIGHPM"]/text())[1]', 'BIGINT') AS [REVERT_HIGHPM_Value],
    record_xml.value('(./Record/ResourceMonitor/Effect[@type="REVERT_HIGHPM"]/@state)[1]', 'VARCHAR(50)') AS [REVERT_HIGHPM_State],
    
    -- MemoryNode
    record_xml.value('(./Record/MemoryNode/@id)[1]', 'INT') AS [MemoryNode_Id],
    record_xml.value('(./Record/MemoryNode/TargetMemory)[1]', 'BIGINT') AS [TargetMemory_KB],
    record_xml.value('(./Record/MemoryNode/ReservedMemory)[1]', 'BIGINT') AS [ReservedMemory_KB],
    record_xml.value('(./Record/MemoryNode/CommittedMemory)[1]', 'BIGINT') AS [CommittedMemory_KB],
    record_xml.value('(./Record/MemoryNode/SharedMemory)[1]', 'BIGINT') AS [SharedMemory_KB],
    record_xml.value('(./Record/MemoryNode/AWEMemory)[1]', 'BIGINT') AS [AWEMemory_KB],
    record_xml.value('(./Record/MemoryNode/PagesMemory)[1]', 'BIGINT') AS [PagesMemory_KB],
    
    -- MemoryRecord (системная память)
    record_xml.value('(./Record/MemoryRecord/MemoryUtilization)[1]', 'INT') AS [MemoryUtilization_%],
    record_xml.value('(./Record/MemoryRecord/TotalPhysicalMemory)[1]', 'BIGINT') AS [TotalPhysicalMemory_KB],
    record_xml.value('(./Record/MemoryRecord/AvailablePhysicalMemory)[1]', 'BIGINT') AS [AvailablePhysicalMemory_KB],
    record_xml.value('(./Record/MemoryRecord/TotalPageFile)[1]', 'BIGINT') AS [TotalPageFile_KB],
    record_xml.value('(./Record/MemoryRecord/AvailablePageFile)[1]', 'BIGINT') AS [AvailablePageFile_KB],
    record_xml.value('(./Record/MemoryRecord/TotalVirtualAddressSpace)[1]', 'BIGINT') AS [TotalVirtualAddressSpace_KB],
    record_xml.value('(./Record/MemoryRecord/AvailableVirtualAddressSpace)[1]', 'BIGINT') AS [AvailableVirtualAddressSpace_KB],
    record_xml.value('(./Record/MemoryRecord/AvailableExtendedVirtualAddressSpace)[1]', 'BIGINT') AS [AvailableExtendedVirtualAddressSpace_KB],
    
    -- Вычисляемые поля для MemoryNode (в МБ и ГБ)
    record_xml.value('(./Record/MemoryNode/TargetMemory)[1]', 'BIGINT') / 1024.0 AS [TargetMemory_MB],
    record_xml.value('(./Record/MemoryNode/ReservedMemory)[1]', 'BIGINT') / 1024.0 AS [ReservedMemory_MB],
    record_xml.value('(./Record/MemoryNode/CommittedMemory)[1]', 'BIGINT') / 1024.0 AS [CommittedMemory_MB],
    record_xml.value('(./Record/MemoryNode/TargetMemory)[1]', 'BIGINT') / 1048576.0 AS [TargetMemory_GB],
    
    -- Процент использования от цели
    CASE 
        WHEN record_xml.value('(./Record/MemoryNode/TargetMemory)[1]', 'BIGINT') > 0
        THEN (record_xml.value('(./Record/MemoryNode/CommittedMemory)[1]', 'BIGINT') * 100.0) / 
             record_xml.value('(./Record/MemoryNode/TargetMemory)[1]', 'BIGINT')
        ELSE 0
    END AS [Committed_%_of_Target],
    
    -- Вычисляемые поля для системной памяти (в МБ и ГБ)
    record_xml.value('(./Record/MemoryRecord/TotalPhysicalMemory)[1]', 'BIGINT') / 1024.0 AS [TotalPhysicalMemory_MB],
    record_xml.value('(./Record/MemoryRecord/AvailablePhysicalMemory)[1]', 'BIGINT') / 1024.0 AS [AvailablePhysicalMemory_MB],
    record_xml.value('(./Record/MemoryRecord/TotalPhysicalMemory)[1]', 'BIGINT') / 1048576.0 AS [TotalPhysicalMemory_GB],
    
    -- Доступная физическая память в процентах
    CASE 
        WHEN record_xml.value('(./Record/MemoryRecord/TotalPhysicalMemory)[1]', 'BIGINT') > 0
        THEN (record_xml.value('(./Record/MemoryRecord/AvailablePhysicalMemory)[1]', 'BIGINT') * 100.0) / 
             record_xml.value('(./Record/MemoryRecord/TotalPhysicalMemory)[1]', 'BIGINT')
        ELSE 0
    END AS [AvailablePhysicalMemory_%],
    
    -- Используемая память SQL Server
    record_xml.value('(./Record/MemoryNode/CommittedMemory)[1]', 'BIGINT') AS [SQL_Committed_KB],
    
    -- Доля SQL Server в физической памяти
    CASE 
        WHEN record_xml.value('(./Record/MemoryRecord/TotalPhysicalMemory)[1]', 'BIGINT') > 0
        THEN (record_xml.value('(./Record/MemoryNode/CommittedMemory)[1]', 'BIGINT') * 100.0) / 
             record_xml.value('(./Record/MemoryRecord/TotalPhysicalMemory)[1]', 'BIGINT')
        ELSE 0
    END AS [SQL_Memory_%_of_Physical]
    
FROM sys.dm_os_ring_buffers rb
CROSS JOIN sys.dm_os_sys_info si
CROSS APPLY (SELECT CAST(rb.record AS XML) AS record_xml) AS x
WHERE rb.ring_buffer_type = 'RING_BUFFER_RESOURCE_MONITOR'
ORDER BY rb.timestamp, [Record_xml_id];

-- запрос для парсинга XML типа RING_BUFFER_SCHEDULER_MONITOR
SELECT 
    ROW_NUMBER() OVER (ORDER BY rb.timestamp DESC) AS [Record id],
    rb.ring_buffer_type AS [type],
    DATEADD(second, (rb.timestamp - si.ms_ticks)/1000, GETDATE()) AS [time],
    
    -- Распарсенные поля из XML
    record_xml.value('(./Record/@id)[1]', 'INT') AS [Record_xml_id],
    
    -- Поля из SystemHealth
    record_xml.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'INT') AS [ProcessUtilization_%],
    record_xml.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'INT') AS [SystemIdle_%],
    record_xml.value('(./Record/SchedulerMonitorEvent/SystemHealth/UserModeTime)[1]', 'BIGINT') AS [UserModeTime],
    record_xml.value('(./Record/SchedulerMonitorEvent/SystemHealth/KernelModeTime)[1]', 'BIGINT') AS [KernelModeTime],
    record_xml.value('(./Record/SchedulerMonitorEvent/SystemHealth/PageFaults)[1]', 'BIGINT') AS [PageFaults],
    record_xml.value('(./Record/SchedulerMonitorEvent/SystemHealth/WorkingSetDelta)[1]', 'BIGINT') AS [WorkingSetDelta],
    record_xml.value('(./Record/SchedulerMonitorEvent/SystemHealth/MemoryUtilization)[1]', 'INT') AS [MemoryUtilization_%],
    
    -- Вычисляемые поля
    record_xml.value('(./Record/SchedulerMonitorEvent/SystemHealth/UserModeTime)[1]', 'BIGINT') / 10000 AS [UserModeTime_ms],
    record_xml.value('(./Record/SchedulerMonitorEvent/SystemHealth/KernelModeTime)[1]', 'BIGINT') / 10000 AS [KernelModeTime_ms],
    
    -- Общее время CPU
    (record_xml.value('(./Record/SchedulerMonitorEvent/SystemHealth/UserModeTime)[1]', 'BIGINT') +
     record_xml.value('(./Record/SchedulerMonitorEvent/SystemHealth/KernelModeTime)[1]', 'BIGINT')) / 10000 AS [TotalCPUTime_ms],
    
    -- Процент CPU в режиме пользователя от общего CPU времени
    CASE 
        WHEN (record_xml.value('(./Record/SchedulerMonitorEvent/SystemHealth/UserModeTime)[1]', 'BIGINT') +
              record_xml.value('(./Record/SchedulerMonitorEvent/SystemHealth/KernelModeTime)[1]', 'BIGINT')) > 0
        THEN (record_xml.value('(./Record/SchedulerMonitorEvent/SystemHealth/UserModeTime)[1]', 'BIGINT') * 100.0) /
             (record_xml.value('(./Record/SchedulerMonitorEvent/SystemHealth/UserModeTime)[1]', 'BIGINT') +
              record_xml.value('(./Record/SchedulerMonitorEvent/SystemHealth/KernelModeTime)[1]', 'BIGINT'))
        ELSE 0
    END AS [UserModePct_of_CPU],
    
    -- Изменение рабочего множества в МБ
    record_xml.value('(./Record/SchedulerMonitorEvent/SystemHealth/WorkingSetDelta)[1]', 'BIGINT') / 1024.0 AS [WorkingSetDelta_MB],
    
    -- Активность системы (100% - SystemIdle)
    100 - record_xml.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'INT') AS [SystemActivity_%]
    
FROM sys.dm_os_ring_buffers rb
CROSS JOIN sys.dm_os_sys_info si
CROSS APPLY (SELECT CAST(rb.record AS XML) AS record_xml) AS x
WHERE rb.ring_buffer_type = 'RING_BUFFER_SCHEDULER_MONITOR'
ORDER BY rb.timestamp, [Record_xml_id];

-- запрос для парсинга XML типа RING_BUFFER_SECURITY_CACHE
SELECT 
    ROW_NUMBER() OVER (ORDER BY rb.timestamp DESC) AS [Record id],
    rb.ring_buffer_type AS [type],
    DATEADD(second, (rb.timestamp - si.ms_ticks)/1000, GETDATE()) AS [time],
    
    -- Распарсенные поля из XML
    record_xml.value('(./Record/@id)[1]', 'INT') AS [Record_xml_id],
    
    -- TokenAndPermUserStore
    record_xml.value('(./Record/TokenAndPermUserStore/@pages_kb)[1]', 'INT') AS [TokenAndPerm_pages_kb],
    
    -- SecContextToken
    record_xml.value('(./Record/TokenAndPermUserStore/SecContextToken/EntriesCount)[1]', 'INT') AS [SecContextToken_EntriesCount],
    record_xml.value('(./Record/TokenAndPermUserStore/SecContextToken/EntriesInserted)[1]', 'INT') AS [SecContextToken_EntriesInserted],
    record_xml.value('(./Record/TokenAndPermUserStore/SecContextToken/EntriesRemoved)[1]', 'INT') AS [SecContextToken_EntriesRemoved],
    
    -- LoginToken
    record_xml.value('(./Record/TokenAndPermUserStore/LoginToken/EntriesCount)[1]', 'INT') AS [LoginToken_EntriesCount],
    record_xml.value('(./Record/TokenAndPermUserStore/LoginToken/EntriesInserted)[1]', 'INT') AS [LoginToken_EntriesInserted],
    record_xml.value('(./Record/TokenAndPermUserStore/LoginToken/EntriesRemoved)[1]', 'INT') AS [LoginToken_EntriesRemoved],
    
    -- UserToken
    record_xml.value('(./Record/TokenAndPermUserStore/UserToken/EntriesCount)[1]', 'INT') AS [UserToken_EntriesCount],
    record_xml.value('(./Record/TokenAndPermUserStore/UserToken/EntriesInserted)[1]', 'INT') AS [UserToken_EntriesInserted],
    record_xml.value('(./Record/TokenAndPermUserStore/UserToken/EntriesRemoved)[1]', 'INT') AS [UserToken_EntriesRemoved],
    
    -- TokenPerm
    record_xml.value('(./Record/TokenAndPermUserStore/TokenPerm/EntriesCount)[1]', 'INT') AS [TokenPerm_EntriesCount],
    record_xml.value('(./Record/TokenAndPermUserStore/TokenPerm/EntriesInserted)[1]', 'INT') AS [TokenPerm_EntriesInserted],
    record_xml.value('(./Record/TokenAndPermUserStore/TokenPerm/EntriesRemoved)[1]', 'INT') AS [TokenPerm_EntriesRemoved],
    
    -- TokenAudit
    record_xml.value('(./Record/TokenAndPermUserStore/TokenAudit/EntriesCount)[1]', 'INT') AS [TokenAudit_EntriesCount],
    record_xml.value('(./Record/TokenAndPermUserStore/TokenAudit/EntriesInserted)[1]', 'INT') AS [TokenAudit_EntriesInserted],
    record_xml.value('(./Record/TokenAndPermUserStore/TokenAudit/EntriesRemoved)[1]', 'INT') AS [TokenAudit_EntriesRemoved],
    
    -- ACRCacheStores
    record_xml.value('(./Record/ACRCacheStores/@pages_kb)[1]', 'INT') AS [ACRCache_pages_kb],
    
    -- SecCtxtACRUserStore
    record_xml.value('(./Record/ACRCacheStores/SecCtxtACRUserStore/NumStores)[1]', 'INT') AS [SecCtxtACRUserStore_NumStores],
    record_xml.value('(./Record/ACRCacheStores/SecCtxtACRUserStore/TotalEntriesCount)[1]', 'INT') AS [SecCtxtACRUserStore_TotalEntriesCount],
    record_xml.value('(./Record/ACRCacheStores/SecCtxtACRUserStore/MaxEntriesPerStore)[1]', 'INT') AS [SecCtxtACRUserStore_MaxEntriesPerStore],
    record_xml.value('(./Record/ACRCacheStores/SecCtxtACRUserStore/MaxEntriesStoreName)[1]', 'VARCHAR(100)') AS [SecCtxtACRUserStore_MaxEntriesStoreName],
    
    -- ACRUserStore
    record_xml.value('(./Record/ACRCacheStores/ACRUserStore/NumStores)[1]', 'INT') AS [ACRUserStore_NumStores],
    record_xml.value('(./Record/ACRCacheStores/ACRUserStore/TotalEntriesCount)[1]', 'INT') AS [ACRUserStore_TotalEntriesCount],
    record_xml.value('(./Record/ACRCacheStores/ACRUserStore/MaxEntriesPerStore)[1]', 'INT') AS [ACRUserStore_MaxEntriesPerStore],
    record_xml.value('(./Record/ACRCacheStores/ACRUserStore/MaxEntriesStoreName)[1]', 'VARCHAR(100)') AS [ACRUserStore_MaxEntriesStoreName],
    
    -- Вычисляемые поля для анализа
    record_xml.value('(./Record/TokenAndPermUserStore/UserToken/EntriesCount)[1]', 'INT') +
    record_xml.value('(./Record/TokenAndPermUserStore/LoginToken/EntriesCount)[1]', 'INT') +
    record_xml.value('(./Record/TokenAndPermUserStore/SecContextToken/EntriesCount)[1]', 'INT') AS [Total_Token_Entries],
    
    record_xml.value('(./Record/TokenAndPermUserStore/UserToken/EntriesInserted)[1]', 'INT') +
    record_xml.value('(./Record/TokenAndPermUserStore/LoginToken/EntriesInserted)[1]', 'INT') +
    record_xml.value('(./Record/TokenAndPermUserStore/SecContextToken/EntriesInserted)[1]', 'INT') AS [Total_Inserted],
    
    record_xml.value('(./Record/TokenAndPermUserStore/UserToken/EntriesRemoved)[1]', 'INT') +
    record_xml.value('(./Record/TokenAndPermUserStore/LoginToken/EntriesRemoved)[1]', 'INT') +
    record_xml.value('(./Record/TokenAndPermUserStore/SecContextToken/EntriesRemoved)[1]', 'INT') AS [Total_Removed],
    
    -- Общее использование памяти
    record_xml.value('(./Record/TokenAndPermUserStore/@pages_kb)[1]', 'INT') + 
    record_xml.value('(./Record/ACRCacheStores/@pages_kb)[1]', 'INT') AS [Total_Security_Cache_KB],
    
    (record_xml.value('(./Record/TokenAndPermUserStore/@pages_kb)[1]', 'INT') + 
     record_xml.value('(./Record/ACRCacheStores/@pages_kb)[1]', 'INT')) / 1024.0 AS [Total_Security_Cache_MB]
    
FROM sys.dm_os_ring_buffers rb
CROSS JOIN sys.dm_os_sys_info si
CROSS APPLY (SELECT CAST(rb.record AS XML) AS record_xml) AS x
WHERE rb.ring_buffer_type = 'RING_BUFFER_SECURITY_CACHE'
ORDER BY rb.timestamp, [Record_xml_id];

-- запрос для парсинга XML типа RING_BUFFER_MEMORY_BROKER
SELECT 
    ROW_NUMBER() OVER (ORDER BY rb.timestamp DESC) AS [Record id],
    rb.ring_buffer_type AS [type],
    DATEADD(second, (rb.timestamp - si.ms_ticks)/1000, GETDATE()) AS [time],
    
    -- Распарсенные поля из XML
    record_xml.value('(./Record/@id)[1]', 'INT') AS [Record_xml_id],
    
    -- Поля из MemoryBroker
    record_xml.value('(./Record/MemoryBroker/DeltaTime)[1]', 'INT') AS [DeltaTime],
    record_xml.value('(./Record/MemoryBroker/Pool)[1]', 'INT') AS [Pool_ID],
    
    -- Описание пула памяти
    CASE record_xml.value('(./Record/MemoryBroker/Pool)[1]', 'INT')
        WHEN 1 THEN 'Small Pool (<8KB)'
        WHEN 2 THEN 'Large Pool (>8KB)'
        WHEN 3 THEN 'Shared Pool'
        ELSE 'Unknown Pool'
    END AS [Pool_Description],
    
    record_xml.value('(./Record/MemoryBroker/Broker)[1]', 'VARCHAR(50)') AS [Broker_Type],
    
    -- Описание брокера
    CASE record_xml.value('(./Record/MemoryBroker/Broker)[1]', 'VARCHAR(50)')
        WHEN 'MEMORYBROKER_FOR_HASHED_DATA_PAGES' THEN 'Hashed Data Pages (Index/Page Cache)'
        WHEN 'MEMORYBROKER_FOR_CACHE' THEN 'General Cache'
        WHEN 'MEMORYBROKER_FOR_QUERY_EXEC' THEN 'Query Execution'
        WHEN 'MEMORYBROKER_FOR_STEAL' THEN 'Stolen Memory'
        WHEN 'MEMORYBROKER_FOR_RESERVED' THEN 'Reserved Memory'
        ELSE record_xml.value('(./Record/MemoryBroker/Broker)[1]', 'VARCHAR(50)')
    END AS [Broker_Description],
    
    record_xml.value('(./Record/MemoryBroker/Notification)[1]', 'VARCHAR(20)') AS [Notification],
    record_xml.value('(./Record/MemoryBroker/MemoryRatio)[1]', 'INT') AS [MemoryRatio],
    record_xml.value('(./Record/MemoryBroker/NewTarget)[1]', 'BIGINT') AS [NewTarget_KB],
    record_xml.value('(./Record/MemoryBroker/Overall)[1]', 'BIGINT') AS [Overall_KB],
    record_xml.value('(./Record/MemoryBroker/Rate)[1]', 'INT') AS [Rate],
    record_xml.value('(./Record/MemoryBroker/CurrentlyPredicted)[1]', 'BIGINT') AS [CurrentlyPredicted_KB],
    record_xml.value('(./Record/MemoryBroker/CurrentlyAllocated)[1]', 'BIGINT') AS [CurrentlyAllocated_KB],
    record_xml.value('(./Record/MemoryBroker/PreviouslyAllocated)[1]', 'BIGINT') AS [PreviouslyAllocated_KB],
    
    -- Вычисляемые поля для анализа
    record_xml.value('(./Record/MemoryBroker/NewTarget)[1]', 'BIGINT') / 1024.0 AS [NewTarget_MB],
    record_xml.value('(./Record/MemoryBroker/Overall)[1]', 'BIGINT') / 1024.0 AS [Overall_MB],
    
    -- Изменение аллокации
    record_xml.value('(./Record/MemoryBroker/CurrentlyAllocated)[1]', 'BIGINT') - 
    record_xml.value('(./Record/MemoryBroker/PreviouslyAllocated)[1]', 'BIGINT') AS [Allocation_Delta_KB]
    
FROM sys.dm_os_ring_buffers rb
CROSS JOIN sys.dm_os_sys_info si
CROSS APPLY (SELECT CAST(rb.record AS XML) AS record_xml) AS x
WHERE rb.ring_buffer_type = 'RING_BUFFER_MEMORY_BROKER'
ORDER BY rb.timestamp, [Record_xml_id];

-- запрос для парсинга XML типа RING_BUFFER_XE_BUFFER_STATE
SELECT 
    ROW_NUMBER() OVER (ORDER BY rb.timestamp DESC) AS [Record id],
    rb.ring_buffer_type AS [type],
    DATEADD(second, (rb.timestamp - si.ms_ticks)/1000, GETDATE()) AS [time],
    
    -- Распарсенные поля из XML
    record_xml.value('(./Record/@id)[1]', 'INT') AS [Record_xml_id],
    
    -- Атрибуты XE_BufferStateRecord
    record_xml.value('(./Record/XE_BufferStateRecord/@id)[1]', 'INT') AS [BufferStateRecord_id],
    record_xml.value('(./Record/XE_BufferStateRecord/@address)[1]', 'VARCHAR(50)') AS [BufferStateRecord_address],
    
    -- Поля внутри XE_BufferStateRecord
    record_xml.value('(./Record/XE_BufferStateRecord/SessionHandle)[1]', 'VARCHAR(50)') AS [SessionHandle],
    record_xml.value('(./Record/XE_BufferStateRecord/BufferMgr)[1]', 'VARCHAR(50)') AS [BufferMgr],
    record_xml.value('(./Record/XE_BufferStateRecord/OldState)[1]', 'VARCHAR(30)') AS [OldState],
    record_xml.value('(./Record/XE_BufferStateRecord/NewState)[1]', 'VARCHAR(30)') AS [NewState]
    
FROM sys.dm_os_ring_buffers rb
CROSS JOIN sys.dm_os_sys_info si
CROSS APPLY (SELECT CAST(rb.record AS XML) AS record_xml) AS x
WHERE rb.ring_buffer_type = 'RING_BUFFER_XE_BUFFER_STATE'
ORDER BY rb.timestamp, [Record_xml_id];

-- запрос для парсинга XML типа RING_BUFFER_HOBT_SCHEMAMGR
SELECT 
    ROW_NUMBER() OVER (ORDER BY rb.timestamp DESC) AS [Record id],
    rb.ring_buffer_type AS [type],
    DATEADD(second, (rb.timestamp - si.ms_ticks)/1000, GETDATE()) AS [time],
    
    -- Распарсенные поля из XML
    record_xml.value('(./Record/@id)[1]', 'INT') AS [Record_xml_id],
    
    -- Поля из operation
    record_xml.value('(./Record/operation/@action)[1]', 'VARCHAR(20)') AS [Action],
    record_xml.value('(./Record/operation/@dbid)[1]', 'INT') AS [DatabaseID],
    record_xml.value('(./Record/operation/@version)[1]', 'BIGINT') AS [Version],
    
    -- Поля из hobt
    record_xml.value('(./Record/hobt/@id)[1]', 'VARCHAR(50)') AS [Hobt_ID],
    record_xml.value('(./Record/hobt/@type)[1]', 'VARCHAR(20)') AS [Hobt_Type],
    
    -- Дополнительная информация о базе данных (если доступно)
    DB_NAME(record_xml.value('(./Record/operation/@dbid)[1]', 'INT')) AS [DatabaseName]
    
FROM sys.dm_os_ring_buffers rb
CROSS JOIN sys.dm_os_sys_info si
CROSS APPLY (SELECT CAST(rb.record AS XML) AS record_xml) AS x
WHERE rb.ring_buffer_type = 'RING_BUFFER_HOBT_SCHEMAMGR'
ORDER BY rb.timestamp, [Record_xml_id];

-- запрос для парсинга XML типа RING_BUFFER_SCHEDULER
SELECT 
    ROW_NUMBER() OVER (ORDER BY rb.timestamp DESC) AS [Record id],
    rb.ring_buffer_type AS [type],
    DATEADD(second, (rb.timestamp - si.ms_ticks)/1000, GETDATE()) AS [time],
    
    -- Распарсенные поля из XML
    record_xml.value('(./Record/@id)[1]', 'INT') AS [Record_xml_id],
    record_xml.value('(./Record/Scheduler/@address)[1]', 'VARCHAR(50)') AS [Scheduler_address],
    record_xml.value('(./Record/Scheduler/Action)[1]', 'VARCHAR(50)') AS [Action],
    record_xml.value('(./Record/Scheduler/TickCount)[1]', 'BIGINT') AS [TickCount],
    record_xml.value('(./Record/Scheduler/SourceWorker)[1]', 'VARCHAR(50)') AS [SourceWorker],
    record_xml.value('(./Record/Scheduler/TargetWorker)[1]', 'VARCHAR(50)') AS [TargetWorker],
    record_xml.value('(./Record/Scheduler/WorkerSignalTime)[1]', 'BIGINT') AS [WorkerSignalTime],
    record_xml.value('(./Record/Scheduler/DiskIOCompleted)[1]', 'BIGINT') AS [DiskIOCompleted],
    record_xml.value('(./Record/Scheduler/TimersExpired)[1]', 'BIGINT') AS [TimersExpired],
    record_xml.value('(./Record/Scheduler/NextTimeout)[1]', 'INT') AS [NextTimeout],
    record_xml.value('(./Record/Scheduler/ReturnCode)[1]', 'VARCHAR(20)') AS [ReturnCode]
FROM sys.dm_os_ring_buffers rb
CROSS JOIN sys.dm_os_sys_info si
CROSS APPLY (SELECT CAST(rb.record AS XML) AS record_xml) AS x
WHERE rb.ring_buffer_type = 'RING_BUFFER_SCHEDULER'
ORDER BY rb.timestamp, [Record_xml_id];

-- запрос для парсинга XML типа RING_BUFFER_EXCEPTION
SELECT 
    ROW_NUMBER() OVER (ORDER BY rb.timestamp DESC) AS [Record id],
    rb.ring_buffer_type AS [type],
    DATEADD(second, (rb.timestamp - si.ms_ticks)/1000, GETDATE()) AS [time],
    
    -- Распарсенные поля из XML
    record_xml.value('(./Record/@id)[1]', 'INT') AS [Record_xml_id],
    
    -- Поля из Exception
    record_xml.value('(./Record/Exception/Task/@address)[1]', 'VARCHAR(50)') AS [Task_address],
    record_xml.value('(./Record/Exception/Error)[1]', 'INT') AS [Error_Number],
    record_xml.value('(./Record/Exception/Severity)[1]', 'INT') AS [Severity],
    record_xml.value('(./Record/Exception/State)[1]', 'INT') AS [State],
    record_xml.value('(./Record/Exception/UserDefined)[1]', 'INT') AS [UserDefined],
    record_xml.value('(./Record/Exception/Origin)[1]', 'INT') AS [Origin],
    
    -- Текст ошибки (если есть соответствие в системном представлении)
    CASE 
        WHEN record_xml.value('(./Record/Exception/Error)[1]', 'INT') IS NOT NULL
        THEN (SELECT TOP 1 text FROM sys.messages WHERE message_id = record_xml.value('(./Record/Exception/Error)[1]', 'INT') AND language_id = 1033)
        ELSE NULL
    END AS [Error_Message],
    
    -- Поля из Stack (первые 5 фреймов для информации)
    record_xml.value('(./Record/Stack/frame[@id="0"])[1]', 'VARCHAR(50)') AS [Stack_frame_0],
    record_xml.value('(./Record/Stack/frame[@id="1"])[1]', 'VARCHAR(50)') AS [Stack_frame_1],
    record_xml.value('(./Record/Stack/frame[@id="2"])[1]', 'VARCHAR(50)') AS [Stack_frame_2],
    record_xml.value('(./Record/Stack/frame[@id="3"])[1]', 'VARCHAR(50)') AS [Stack_frame_3],
    record_xml.value('(./Record/Stack/frame[@id="4"])[1]', 'VARCHAR(50)') AS [Stack_frame_4],
    
    -- Количество фреймов в стеке
    record_xml.value('count(./Record/Stack/frame)', 'INT') AS [Stack_Frame_Count]
    
FROM sys.dm_os_ring_buffers rb
CROSS JOIN sys.dm_os_sys_info si
CROSS APPLY (SELECT CAST(rb.record AS XML) AS record_xml) AS x
WHERE rb.ring_buffer_type = 'RING_BUFFER_EXCEPTION'
ORDER BY rb.timestamp, [Record_xml_id];

-- запрос для парсинга XML типа RING_BUFFER_QE_MEM_BUFF_POOL_RESERVE
SELECT 
    ROW_NUMBER() OVER (ORDER BY rb.timestamp DESC) AS [Record id],
    rb.ring_buffer_type AS [type],
    DATEADD(second, (rb.timestamp - si.ms_ticks)/1000, GETDATE()) AS [time],
    
    -- Распарсенные поля из XML
    record_xml.value('(./Record/@id)[1]', 'INT') AS [Record_xml_id],
    
    -- Поля из QueryMemoryBufferPoolReserve
    record_xml.value('(./Record/QueryMemoryBufferPoolReserve/CountReserved)[1]', 'INT') AS [CountReserved],
    record_xml.value('(./Record/QueryMemoryBufferPoolReserve/Operation)[1]', 'VARCHAR(50)') AS [Operation],
    record_xml.value('(./Record/QueryMemoryBufferPoolReserve/Result)[1]', 'VARCHAR(20)') AS [Result],
    record_xml.value('(./Record/QueryMemoryBufferPoolReserve/Outstanding)[1]', 'INT') AS [Outstanding],
    
    -- Поля из Stack (можно добавить несколько первых фреймов для информации)
    record_xml.value('(./Record/Stack/frame[@id="0"])[1]', 'VARCHAR(50)') AS [Stack_frame_0],
    record_xml.value('(./Record/Stack/frame[@id="1"])[1]', 'VARCHAR(50)') AS [Stack_frame_1],
    record_xml.value('(./Record/Stack/frame[@id="2"])[1]', 'VARCHAR(50)') AS [Stack_frame_2],
    record_xml.value('(./Record/Stack/frame[@id="3"])[1]', 'VARCHAR(50)') AS [Stack_frame_3],
    record_xml.value('(./Record/Stack/frame[@id="4"])[1]', 'VARCHAR(50)') AS [Stack_frame_4],
    
    -- Количество фреймов в стеке
    record_xml.value('count(./Record/Stack/frame)', 'INT') AS [Stack_Frame_Count]
    
FROM sys.dm_os_ring_buffers rb
CROSS JOIN sys.dm_os_sys_info si
CROSS APPLY (SELECT CAST(rb.record AS XML) AS record_xml) AS x
WHERE rb.ring_buffer_type = 'RING_BUFFER_QE_MEM_BUFF_POOL_RESERVE'
ORDER BY rb.timestamp, [Record_xml_id];

-- запрос для парсинга XML типа RING_BUFFER_CLRHOSTTASK
SELECT 
    ROW_NUMBER() OVER (ORDER BY rb.timestamp DESC) AS [Record id],
    rb.ring_buffer_type AS [type],
    DATEADD(second, (rb.timestamp - si.ms_ticks)/1000, GETDATE()) AS [time],
    
    -- Распарсенные поля из XML
    record_xml.value('(./Record/@id)[1]', 'INT') AS [Record_xml_id],
    
    -- Action
    record_xml.value('(./Record/Action)[1]', 'VARCHAR(100)') AS [Action],
    
    -- Атрибуты HostTask
    record_xml.value('(./Record/HostTask/@address)[1]', 'VARCHAR(50)') AS [HostTask_address],
    record_xml.value('(./Record/HostTask/@state)[1]', 'VARCHAR(50)') AS [HostTask_state],
    record_xml.value('(./Record/HostTask/@abortState)[1]', 'VARCHAR(50)') AS [HostTask_abortState],
    record_xml.value('(./Record/HostTask/@clrTask)[1]', 'VARCHAR(50)') AS [HostTask_clrTask],
    record_xml.value('(./Record/HostTask/@threadAffinityCount)[1]', 'INT') AS [threadAffinityCount],
    record_xml.value('(./Record/HostTask/@leaveRuntimeCount)[1]', 'INT') AS [leaveRuntimeCount],
    record_xml.value('(./Record/HostTask/@nonYieldingCount)[1]', 'INT') AS [nonYieldingCount],
    record_xml.value('(./Record/HostTask/@threadId)[1]', 'INT') AS [threadId],
    
    -- HRESULT в разных форматах
    record_xml.value('(./Record/HostTask/@hresult)[1]', 'INT') AS [hresult_decimal],
    '0x' + CONVERT(VARCHAR(8), CONVERT(VARBINARY(4), record_xml.value('(./Record/HostTask/@hresult)[1]', 'INT')), 2) AS [hresult_hex]
    
FROM sys.dm_os_ring_buffers rb
CROSS JOIN sys.dm_os_sys_info si
CROSS APPLY (SELECT CAST(rb.record AS XML) AS record_xml) AS x
WHERE rb.ring_buffer_type = 'RING_BUFFER_CLRHOSTTASK'
ORDER BY rb.timestamp DESC, [Record_xml_id];

-- запрос для парсинга XML типа RING_BUFFER_XE_LOG
SELECT 
    ROW_NUMBER() OVER (ORDER BY rb.timestamp DESC) AS [Record id],
    rb.ring_buffer_type AS [type],
    DATEADD(second, (rb.timestamp - si.ms_ticks)/1000, GETDATE()) AS [time],
    
    -- Распарсенные поля из XML
    record_xml.value('(./Record/@id)[1]', 'INT') AS [Record_xml_id],
    
    -- Поле из XE_LogRecord
    record_xml.value('(./Record/XE_LogRecord/@message)[1]', 'NVARCHAR(1000)') AS [Message],
    
    -- Дополнительный парсинг сообщения для извлечения числа, если нужно
    CASE 
        WHEN record_xml.value('(./Record/XE_LogRecord/@message)[1]', 'NVARCHAR(1000)') LIKE '%Результат модуля построения XE Engine: %'
        THEN TRY_CAST(
                REPLACE(
                    REPLACE(
                        record_xml.value('(./Record/XE_LogRecord/@message)[1]', 'NVARCHAR(1000)'),
                        'Результат модуля построения XE Engine: ', ''
                    ),
                    '.', ''
                ) AS INT
             )
        ELSE NULL
    END AS [Engine_Result_Code],
    
    -- Уровень важности сообщения (примерная классификация)
    CASE 
        WHEN record_xml.value('(./Record/XE_LogRecord/@message)[1]', 'NVARCHAR(1000)') LIKE '%error%' 
            OR record_xml.value('(./Record/XE_LogRecord/@message)[1]', 'NVARCHAR(1000)') LIKE '%ошибк%'
        THEN 'ERROR'
        WHEN record_xml.value('(./Record/XE_LogRecord/@message)[1]', 'NVARCHAR(1000)') LIKE '%warning%'
            OR record_xml.value('(./Record/XE_LogRecord/@message)[1]', 'NVARCHAR(1000)') LIKE '%предупрежд%'
        THEN 'WARNING'
        WHEN record_xml.value('(./Record/XE_LogRecord/@message)[1]', 'NVARCHAR(1000)') LIKE '%success%'
            OR record_xml.value('(./Record/XE_LogRecord/@message)[1]', 'NVARCHAR(1000)') LIKE '%успеш%'
        THEN 'SUCCESS'
        ELSE 'INFO'
    END AS [Message_Level]
    
FROM sys.dm_os_ring_buffers rb
CROSS JOIN sys.dm_os_sys_info si
CROSS APPLY (SELECT CAST(rb.record AS XML) AS record_xml) AS x
WHERE rb.ring_buffer_type = 'RING_BUFFER_XE_LOG'
ORDER BY rb.timestamp DESC, [Record_xml_id];
