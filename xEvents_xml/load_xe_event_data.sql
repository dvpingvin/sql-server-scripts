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

SELECT * FROM #tmp_xe_event_data WHERE timestamp_utc > DATEADD(day, -2, GETUTCDATE()) -- За последние 2 суток
