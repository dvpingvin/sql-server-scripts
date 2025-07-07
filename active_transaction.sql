SELECT
t.transaction_id,
s.session_id,
DB_NAME(dtr.database_id) AS database_name,
s.session_id,
s.login_name,
s.host_name,
s.program_name,
t.name AS transaction_name,
t.transaction_begin_time,
DATEDIFF(MINUTE, t.transaction_begin_time, GETDATE()) AS duration_minutes,
CASE t.transaction_type
WHEN 1 THEN 'Read/write'
WHEN 2 THEN 'Read-only'
WHEN 3 THEN 'System'
WHEN 4 THEN 'Distributed'
END AS transaction_type,
CASE t.transaction_state
WHEN 0 THEN 'Not initialized'
WHEN 1 THEN 'Initialized, not started'
WHEN 2 THEN 'Active'
WHEN 3 THEN 'Ended'
WHEN 4 THEN 'Commit initiated'
WHEN 5 THEN 'Prepared, awaiting resolution'
WHEN 6 THEN 'Committed'
WHEN 7 THEN 'Rolling back'
WHEN 8 THEN 'Rolled back'
END AS transaction_state,
t.transaction_uow
FROM
sys.dm_tran_active_transactions t
JOIN
sys.dm_tran_database_transactions dtr ON t.transaction_id = dtr.transaction_id
LEFT JOIN
sys.dm_exec_sessions s ON t.transaction_id = s.session_id
--WHERE
--dtr.database_id = DB_ID('ВашаБазаДанных') -- Укажите имя вашей БД
ORDER BY
t.transaction_begin_time;
