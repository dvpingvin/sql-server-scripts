DECLARE @event_file_path NVARCHAR(1000)

SELECT @event_file_path = CAST(xt.target_data AS XML).value('(EventFileTarget/File/@name)[1]', 'VARCHAR(MAX)')
FROM sys.dm_xe_sessions xs WITH (NOLOCK)
JOIN sys.dm_xe_session_targets xt WITH (NOLOCK) ON xs.address = xt.event_session_address
WHERE xt.target_name = 'event_file' AND xs.name = N'system_health'

SELECT DATEADD(hour, 3, [timestamp_utc]) AS [timestamp_msk], CONVERT(xml, event_data).query('/event/data/value/child::*') AS [xml_deadlock_report]
FROM sys.fn_xe_file_target_read_file (@event_file_path, null, null, null)
WHERE object_name = 'xml_deadlock_report'
/*Чтобы посмотреть отчёт о взаимных блокировках (deadlocks), XML-файлы из [xml_deadlock_report] нужно сохранить как файлы с расширением .xdl*/
