SET NOCOUNT ON

USE [master];
GO

DECLARE @LoginName NVARCHAR(128) = '<YourLoginName>'; -- Замените на имя вашего логина
DECLARE @OutputScript NVARCHAR(MAX) = '';
DECLARE @Collation NVARCHAR(128) = 'DATABASE_DEFAULT';

-- Проверка и вывод инструкции
IF @LoginName = '<YourLoginName>'
BEGIN
PRINT '####################################################################';
PRINT '# #';
PRINT '# ВНИМАНИЕ: Вы не указали имя логина для анализа! #';
PRINT '# #';
PRINT '# Пожалуйста, замените "<YourLoginName>" в строке: #';
PRINT '# DECLARE @LoginName NVARCHAR(128) = "<YourLoginName>"; #';
PRINT '# на реальное имя логина, например: #';
PRINT '# DECLARE @LoginName NVARCHAR(128) = "MyDomain\MyUser"; #';
PRINT '# или #';
PRINT '# DECLARE @LoginName NVARCHAR(128) = "SQL_Login"; #';
PRINT '# #';
PRINT '####################################################################';
RETURN;
END
 
-- Header information
SET @OutputScript = @OutputScript + N'-- =============================================' + CHAR(13) + CHAR(10);
SET @OutputScript = @OutputScript + N'-- Permission Script for Login: ' + @LoginName COLLATE DATABASE_DEFAULT + CHAR(13) + CHAR(10);
SET @OutputScript = @OutputScript + N'-- Generated on: ' + CONVERT(NVARCHAR(30), GETDATE(), 120) + CHAR(13) + CHAR(10);
SET @OutputScript = @OutputScript + N'-- =============================================' + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10);
 
-- Check if login exists
SET @OutputScript = @OutputScript + N'-- Check if login exists and create if missing' + CHAR(13) + CHAR(10);
SET @OutputScript = @OutputScript + N'IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = ''' + @LoginName COLLATE DATABASE_DEFAULT + ''')' + CHAR(13) + CHAR(10);
SET @OutputScript = @OutputScript + N'BEGIN' + CHAR(13) + CHAR(10);
SET @OutputScript = @OutputScript + N'    CREATE LOGIN [' + @LoginName COLLATE DATABASE_DEFAULT + '] ';
 
-- Get login type and SID to properly recreate it
DECLARE @LoginType NVARCHAR(60), @SID VARBINARY(85), @PWD NVARCHAR(128), @IsDisabled BIT;
SELECT 
    @LoginType = CASE WHEN type IN ('U', 'G') THEN 'FROM WINDOWS' ELSE 'WITH PASSWORD' END,
    @SID = sid,
    @PWD = CASE WHEN type IN ('U', 'G') THEN NULL ELSE CONVERT(NVARCHAR(128), LOGINPROPERTY(name, 'PasswordHash'), 1) END,
    @IsDisabled = is_disabled
FROM sys.server_principals 
WHERE name = @LoginName COLLATE DATABASE_DEFAULT;
 
IF @LoginType = 'FROM WINDOWS'
    SET @OutputScript = @OutputScript + N'FROM WINDOWS;' + CHAR(13) + CHAR(10);
ELSE
    SET @OutputScript = @OutputScript + N'WITH PASSWORD = ' + ISNULL(@PWD, 'NULL') + ' HASHED, SID = ' + CONVERT(NVARCHAR(100), @SID, 1) + ';' + CHAR(13) + CHAR(10);
 
SET @OutputScript = @OutputScript + N'END' + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10);
 
-- Handle disabled status
IF @IsDisabled = 1
    SET @OutputScript = @OutputScript + N'ALTER LOGIN [' + @LoginName COLLATE DATABASE_DEFAULT + '] DISABLE;' + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10);
 
-- Server role memberships
SET @OutputScript = @OutputScript + N'-- Server role memberships' + CHAR(13) + CHAR(10);
DECLARE @ServerRoles TABLE (RoleName NVARCHAR(128) COLLATE DATABASE_DEFAULT);
INSERT INTO @ServerRoles
SELECT r.name COLLATE DATABASE_DEFAULT
FROM sys.server_role_members rm
JOIN sys.server_principals r ON rm.role_principal_id = r.principal_id
JOIN sys.server_principals m ON rm.member_principal_id = m.principal_id
WHERE m.name = @LoginName COLLATE DATABASE_DEFAULT;
 
DECLARE @RoleName NVARCHAR(128);
DECLARE RoleCursor CURSOR FOR SELECT RoleName FROM @ServerRoles;
OPEN RoleCursor;
FETCH NEXT FROM RoleCursor INTO @RoleName;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @OutputScript = @OutputScript + N'ALTER SERVER ROLE [' + @RoleName + '] ADD MEMBER [' + @LoginName COLLATE DATABASE_DEFAULT + '];' + CHAR(13) + CHAR(10);
    FETCH NEXT FROM RoleCursor INTO @RoleName;
END
CLOSE RoleCursor;
DEALLOCATE RoleCursor;
SET @OutputScript = @OutputScript + CHAR(13) + CHAR(10);
 
-- Server-level permissions
SET @OutputScript = @OutputScript + N'-- Server-level permissions' + CHAR(13) + CHAR(10);
DECLARE @ServerPerms TABLE (Permission NVARCHAR(128) COLLATE DATABASE_DEFAULT, StateDesc NVARCHAR(60) COLLATE DATABASE_DEFAULT);
INSERT INTO @ServerPerms
SELECT 
    permission_name COLLATE DATABASE_DEFAULT,
    state_desc COLLATE DATABASE_DEFAULT
FROM sys.server_permissions p
JOIN sys.server_principals s ON p.grantee_principal_id = s.principal_id
WHERE s.name = @LoginName COLLATE DATABASE_DEFAULT AND p.type <> 'COSQ';
 
DECLARE @ServerPerm NVARCHAR(128), @ServerState NVARCHAR(60);
DECLARE ServerPermCursor CURSOR FOR SELECT Permission, StateDesc FROM @ServerPerms;
OPEN ServerPermCursor;
FETCH NEXT FROM ServerPermCursor INTO @ServerPerm, @ServerState;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @OutputScript = @OutputScript + @ServerState + ' ' + @ServerPerm + ' TO [' + @LoginName COLLATE DATABASE_DEFAULT + '];' + CHAR(13) + CHAR(10);
    FETCH NEXT FROM ServerPermCursor INTO @ServerPerm, @ServerState;
END
CLOSE ServerPermCursor;
DEALLOCATE ServerPermCursor;
SET @OutputScript = @OutputScript + CHAR(13) + CHAR(10);
 
-- Database mappings and permissions
SET @OutputScript = @OutputScript + N'-- Database mappings and permissions' + CHAR(13) + CHAR(10);
DECLARE @DBName NVARCHAR(128);
DECLARE DBCursor CURSOR FOR 
SELECT name COLLATE DATABASE_DEFAULT FROM sys.databases 
WHERE state = 0 -- Only online databases
AND name NOT IN ('master', 'tempdb', 'model', 'msdb') -- Skip system DBs or include if needed
ORDER BY name;
 
OPEN DBCursor;
FETCH NEXT FROM DBCursor INTO @DBName;
WHILE @@FETCH_STATUS = 0
BEGIN
    DECLARE @SQL NVARCHAR(MAX);
    
    -- Check if user exists in this database
    SET @SQL = N'
    USE [' + @DBName + N'];
    IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = ''' + @LoginName + ''' COLLATE DATABASE_DEFAULT)
    BEGIN
        SELECT ''USE [' + @DBName + N'];'' AS Command;
        
        -- Database user creation
        SELECT ''CREATE USER ['' + name COLLATE DATABASE_DEFAULT + ''] FOR LOGIN ['' + name COLLATE DATABASE_DEFAULT + '']'' + 
               CASE WHEN default_schema_name IS NOT NULL THEN '' WITH DEFAULT_SCHEMA = ['' + default_schema_name COLLATE DATABASE_DEFAULT + '']'' ELSE '''' END + '';''
        FROM sys.database_principals 
        WHERE name = ''' + @LoginName + ''' COLLATE DATABASE_DEFAULT AND type IN (''S'', ''U'', ''G'');
        
        -- Database role memberships
        SELECT ''ALTER ROLE ['' + r.name COLLATE DATABASE_DEFAULT + ''] ADD MEMBER ['' + m.name COLLATE DATABASE_DEFAULT + ''];''
        FROM sys.database_role_members rm
        JOIN sys.database_principals r ON rm.role_principal_id = r.principal_id
        JOIN sys.database_principals m ON rm.member_principal_id = m.principal_id
        WHERE m.name = ''' + @LoginName + ''' COLLATE DATABASE_DEFAULT;
        
        -- Database-level permissions
        SELECT p.state_desc COLLATE DATABASE_DEFAULT + '' '' + p.permission_name COLLATE DATABASE_DEFAULT + '' TO ['' + u.name COLLATE DATABASE_DEFAULT + ''];''
        FROM sys.database_permissions p
        JOIN sys.database_principals u ON p.grantee_principal_id = u.principal_id
        WHERE u.name = ''' + @LoginName + ''' COLLATE DATABASE_DEFAULT AND p.class = 0;
        
        -- Object-level permissions
        SELECT 
            p.state_desc COLLATE DATABASE_DEFAULT + '' '' + p.permission_name COLLATE DATABASE_DEFAULT + '' ON ['' + SCHEMA_NAME(o.schema_id) COLLATE DATABASE_DEFAULT + ''].['' + o.name COLLATE DATABASE_DEFAULT + '']'' +
            CASE WHEN c.name IS NOT NULL THEN ''(['' + c.name COLLATE DATABASE_DEFAULT + ''])'' ELSE '''' END +
            '' TO ['' + u.name COLLATE DATABASE_DEFAULT + ''];''
        FROM sys.database_permissions p
        JOIN sys.database_principals u ON p.grantee_principal_id = u.principal_id
        LEFT JOIN sys.objects o ON p.major_id = o.object_id AND p.class = 1
        LEFT JOIN sys.columns c ON p.major_id = c.object_id AND p.minor_id = c.column_id AND p.class = 1
        WHERE u.name = ''' + @LoginName + ''' COLLATE DATABASE_DEFAULT AND p.class IN (1, 3);
    END';
    
    DECLARE @TempTable TABLE (Command NVARCHAR(MAX) COLLATE DATABASE_DEFAULT);
    INSERT INTO @TempTable EXEC sp_executesql @SQL;
    
    SELECT @OutputScript = @OutputScript + Command + CHAR(13) + CHAR(10) FROM @TempTable;
    
    FETCH NEXT FROM DBCursor INTO @DBName;
END
CLOSE DBCursor;
DEALLOCATE DBCursor;
 
-- Output the complete script
PRINT @OutputScript;
-- SELECT @OutputScript AS PermissionScript; -- Alternative output method
