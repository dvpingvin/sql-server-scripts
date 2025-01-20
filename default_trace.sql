SELECT
id, status, path, max_size, max_files, is_default, start_time, last_event_time, event_count
FROM sys.traces

SELECT *
FROM fn_trace_gettable
('D:\MSSQL14.MSSQLSERVER\MSSQL\Log\log_2998.trc', default);
GO

SELECT e.trace_event_id, e.name, c.category_id, c.name
FROM sys.trace_categories c
JOIN sys.trace_events e ON c.category_id = e.category_id

SELECT t.*
FROM sys.traces i
CROSS APPLY sys.fn_trace_gettable([path], DEFAULT) t
WHERE i.is_default = 1
--AND t.EventClass IN (14, 20, 104, 105, 106, 107, 108, 154, 159) -- Trace Event 
