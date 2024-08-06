USE [master]
GO
DECLARE @HideInstance INT
DECLARE @NamedPipesEnabled INT
DECLARE @NumErrorLogs INT
DECLARE @IsErrorReportingEnabled INT
DECLARE @ErrorLogSizeInKb INT

EXECUTE master.sys.xp_instance_regread
    'HKEY_LOCAL_MACHINE',
    'Software\Microsoft\MSSQLSERVER\MSSQLServer\SuperSocketNetLib\',
    'HideInstance', @HideInstance OUTPUT
EXECUTE master.sys.xp_instance_regread
    'HKEY_LOCAL_MACHINE',
    'Software\Microsoft\MSSQLServer\MSSQLServer\SuperSocketNetLib\Np\',
    'Enabled', @NamedPipesEnabled OUTPUT
EXECUTE master.sys.xp_instance_regread
    'HKEY_LOCAL_MACHINE',
    'Software\Microsoft\MSSQLServer\CPE\',
    'EnableErrorReporting', @IsErrorReportingEnabled OUTPUT
EXECUTE master.sys.xp_instance_regread
    'HKEY_LOCAL_MACHINE',
    'Software\Microsoft\MSSQLSERVER\MSSQLServer\',
    'NumErrorLogs', @NumErrorLogs OUTPUT 
EXECUTE master.sys.xp_instance_regread
    'HKEY_LOCAL_MACHINE',
    'Software\Microsoft\MSSQLServer\MSSQLServer\',
    'ErrorLogSizeInKb', @ErrorLogSizeInKb OUTPUT

SELECT 
	SERVERPROPERTY('SERVERNAME') AS [ServerName], 
	@HideInstance AS [HideInstance],
	@NamedPipesEnabled AS [NamedPipesEnabled],
	@IsErrorReportingEnabled AS [IsErrorReportingEnabled], 
	@NumErrorLogs AS [NumErrorLogs], -- NULL means never changed and has default value (= 6), 0 means was changed to default value (= 6)
	@ErrorLogSizeInKb AS [ErrorLogSizeInKb], -- NULL means never changed and has default value ('Unlimited'), 0 means was changed to default value ('Unlimited')
	SERVERPROPERTY('ErrorLogFileName') AS 'Error log file location'
GO
