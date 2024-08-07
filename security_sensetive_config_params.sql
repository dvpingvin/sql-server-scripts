SELECT [name], [description], [value] AS [configurated_value], [value_in_use], [is_dynamic], [is_advanced], [configuration_id] 
FROM sys.configurations 
WHERE 
[name] IN (
'Ad Hoc Distributed Queries',
'clr enabled',
'clr strict security',
'cross db ownership chaining',
'Database Mail XPs',
'default trace enabled',
'Ole Automation Procedures',
'remote access',
'remote admin connections',
'scan for startup procs',
'xp_cmdshell'
)
ORDER BY [name]
