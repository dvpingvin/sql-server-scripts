select count (*) as session_total_amount from sys.dm_exec_sessions s1;

select count (*) as session_runnable_amount from sys.dm_exec_sessions s2
where s2.status = 'running';
