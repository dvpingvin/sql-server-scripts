select distinct program_name, client_interface_name, nt_domain, nt_user_name from sys.dm_exec_sessions
order by 1