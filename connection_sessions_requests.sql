SELECT S.login_time, S.session_id, R.request_id,
S.host_name, client_net_address, client_tcp_port, net_transport, program_name, login_name, C.auth_scheme, DB_NAME(R.database_id) AS db_name,
R.command, R.status,
(select text from sys.dm_exec_sql_text(sql_handle)) as [Query Text], *
FROM
  sys.dm_exec_connections AS C
RIGHT JOIN sys.dm_exec_sessions AS S ON C.session_id = S.session_id
LEFT JOIN sys.dm_exec_requests AS R ON S.session_id = R.session_id
WHERE 1=1
--AND S.login_name = '<login_name>'
--AND S.host_name = '<host_name>'
--AND S.session_id = <session_id>
--AND C.connection_id IS NOT NULL
--AND S.database_id IS NOT NULL
--AND S.login_name = 'ggdirect'
ORDER BY S.login_time DESC
