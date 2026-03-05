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
