SELECT [name], [description], [value] AS [configurated_value], [value_in_use], [is_dynamic], [is_advanced], [configuration_id] 
FROM sys.configurations 
WHERE 
[name] IN (
'Ad Hoc Distributed Queries',
'clr enabled',
'clr strict security',
'cross db ownership chaining',
'Database Mail XPs',
'Ole Automation Procedures',
'remote access',
'remote admin connections',
'scan for startup procs',
'xp_cmdshell'
)
OR 
[configuration_id] IN (
16391,
1562,
1587,
400,
16386,
16388,
117,
1576,
1547,
16390
)
ORDER BY [name]
