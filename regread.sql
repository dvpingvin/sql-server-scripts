USE [master]
GO
DECLARE @HideInstance INT
DECLARE @NamedPipesEnabled INT
DECLARE @PipeName INT
DECLARE @SharedMemoryEnabled INT
DECLARE @TCPEnabled INT
DECLARE @TcpPort INT
DECLARE @TcpDynamicPorts INT
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
    'Software\Microsoft\MSSQLServer\MSSQLServer\SuperSocketNetLib\Np\',
    'PipeName', @PipeName OUTPUT
EXECUTE master.sys.xp_instance_regread
    'HKEY_LOCAL_MACHINE',
    'Software\Microsoft\MSSQLServer\MSSQLServer\SuperSocketNetLib\Sm\',
    'Enabled', @SharedMemoryEnabled OUTPUT
EXECUTE master.sys.xp_instance_regread
    'HKEY_LOCAL_MACHINE',
    'Software\Microsoft\MSSQLServer\MSSQLServer\SuperSocketNetLib\Tcp\',
    'Enabled', @TCPEnabled OUTPUT
EXECUTE master.sys.xp_instance_regread
    'HKEY_LOCAL_MACHINE',
    'Software\Microsoft\MSSQLServer\MSSQLServer\SuperSocketNetLib\Tcp\IPAll\',
    'TcpPort', @TcpPort OUTPUT
EXECUTE master.sys.xp_instance_regread
    'HKEY_LOCAL_MACHINE',
    'Software\Microsoft\MSSQLServer\MSSQLServer\SuperSocketNetLib\Tcp\IPAll\',
    'TcpDynamicPorts', @TcpDynamicPorts OUTPUT
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
	@PipeName AS [PipeName],
	@SharedMemoryEnabled AS [SharedMemoryEnabled],
	@TCPEnabled AS [TCPEnabled],
	@TcpPort AS [TcpPort],
	@TcpDynamicPorts AS [TcpDynamicPorts],
	@IsErrorReportingEnabled AS [IsErrorReportingEnabled],
	CASE WHEN @NumErrorLogs IS NULL THEN 6 ELSE @NumErrorLogs END AS [NumErrorLogs], 
	CASE WHEN @ErrorLogSizeInKb IS NULL THEN 'Unlimited' ELSE CAST (@ErrorLogSizeInKb AS VARCHAR(6)) END AS [ErrorLogSizeInKb],
	SERVERPROPERTY('ErrorLogFileName') AS 'Error log file location'
GO
