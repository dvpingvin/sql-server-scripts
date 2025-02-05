DROP TABLE if exists #LoginsRemote;
DROP TABLE if exists #LoginsComparison;
DROP TABLE if exists #NodeAG;

DECLARE
    @stepdId INT = 0,
    @debug BIT = 0;
                DECLARE @check_exp NVARCHAR(3)
                DECLARE @check_pol NVARCHAR(3)

DECLARE
    @SQLStr NVARCHAR(MAX),
    @SQLQuery NVARCHAR(MAX),
    @cmd NVARCHAR(MAX),
    @replica_server_name NVARCHAR(255),
    @LoginLocal NVARCHAR(255),
    @LoginRemoute NVARCHAR(255),
    @DisabledRemoute BIT,
    @PassHashRemoute NVARCHAR(255),
    @is_policy_checked BIT,
    @is_expiration_checked BIT,
    @sidremote NVARCHAR(255),
    @role INT,
    @ReQ INT,
    @modify_dateRemoute DATETIME,
    @MAXmodify_dateRemoute DATETIME,
    @modify_dateLocal DATETIME;

-- Создание временных таблиц для хранения данных
CREATE TABLE #LoginsRemote (
    Login NVARCHAR(255),
    LoginSid NVARCHAR(500),
    PasswordHash NVARCHAR(500),
    Is_Disabled BIT,
    Modify_Date DATETIME,
    Is_Policy_Checked BIT,
    Is_Expiration_Checked BIT,
    ServerName NVARCHAR(255)
);

CREATE TABLE #LoginsComparison (
    LoginRemoute NVARCHAR(255),
    LoginLocal NVARCHAR(255),
    SidRemoute NVARCHAR(500),
    SidLocal NVARCHAR(500),
    PassHashRemoute NVARCHAR(500),
    PassHashLocal NVARCHAR(500),
    DisabledRemoute BIT,
    DisabledLocal BIT,
    Modify_DateRemoute DATETIME,
    MAXModify_DateRemoute DATETIME,
    Modify_DateLocal DATETIME,
    Is_Policy_CheckedLocal BIT,
    Is_Expiration_CheckedLocal BIT,
    Is_Policy_CheckedRemote BIT,
    Is_Expiration_CheckedRemote BIT,
    ServerNameRemoute NVARCHAR(255),
    ServerNameLocal NVARCHAR(255)
);

CREATE TABLE #NodeAG (
    Replica_Server_Name NVARCHAR(255)
);

-- Заполнение таблицы реплик, исключая текущий сервер
INSERT INTO #NodeAG (Replica_Server_Name)
SELECT DISTINCT replica_server_name
FROM sys.availability_replicas
WHERE replica_server_name != @@SERVERNAME;

SELECT * FROM #NodeAG;

-- Определение SQL запроса для получения логинов с удаленных серверов
SET @SQLQuery = '
SELECT
    name,
    sys.fn_varbintohexstr(sid) AS sid,
    sys.fn_varbintohexstr(password_hash) AS passwordHash,
    is_disabled,
    is_policy_checked,
    is_expiration_checked,
    modify_date,
    @@SERVERNAME AS ServerName
FROM sys.sql_logins
WHERE name NOT LIKE ''##%''
  AND name NOT IN (''sa'', ''zabbix_mssql'', ''SqldbaTest'', ''Sqldba'', ''LoginsSync'')
';

-- Получение логинов с удаленных серверов и вставка в временную таблицу #LoginsRemote
DECLARE @ReplicaCount INT = (SELECT COUNT(*) FROM #NodeAG);
DECLARE @CurrentReplica INT = 1;

PRINT '@ReplicaCount:'+ cast(@ReplicaCount as varchar)

WHILE @CurrentReplica <= @ReplicaCount
BEGIN
    SELECT @replica_server_name = Replica_Server_Name
    FROM (
        SELECT Replica_Server_Name, ROW_NUMBER() OVER (ORDER BY Replica_Server_Name) AS RowNum
        FROM #NodeAG
    ) AS Replicas
    WHERE RowNum = @CurrentReplica;

    -- ЕСТЬ @replica_server_name ИЗ КЛАСТЕРА – надо по лайку найти линкед сервер из списка (он может быть с доменом и портом)
    SELECT top 1 @replica_server_name = name
    FROM sys.servers
    WHERE name LIKE @replica_server_name + '%'
    order by len(name); --берем короткий
    
    PRINT 'replica_server_name:' + @replica_server_name;
    SET @SQLStr = 'EXEC (''' + REPLACE(@SQLQuery, '''', '''''') + ''') at [' + @replica_server_name + '];';
    --PRINT ' sql at:' + @SQLStr;
    INSERT INTO #LoginsRemote (Login, LoginSid, PasswordHash, Is_Disabled, Is_Policy_Checked, Is_Expiration_Checked, Modify_Date, ServerName)
    EXEC (@SQLStr);
    SET @CurrentReplica = @CurrentReplica + 1;
END

SELECT 'LoginsRemote' AS LoginsRemote, * FROM #LoginsRemote;

-- Сравнение удаленных логинов с локальными
INSERT INTO #LoginsComparison (
    LoginRemoute,
    LoginLocal,
    SidRemoute,
    SidLocal,
    PassHashRemoute,
    PassHashLocal,
    DisabledRemoute,
    DisabledLocal,
    Modify_DateRemoute,
    MAXModify_DateRemoute,
    Modify_DateLocal,
    Is_Policy_CheckedLocal,
    Is_Expiration_CheckedLocal,
    Is_Policy_CheckedRemote,
    Is_Expiration_CheckedRemote,
    ServerNameRemoute,
    ServerNameLocal
)

SELECT
    r.Login AS LoginRemoute,
    l.name AS LoginLocal,
    r.LoginSid AS SidRemoute,
    sys.fn_varbintohexstr(l.sid) AS SidLocal,
    r.PasswordHash AS PassHashRemoute,
    sys.fn_varbintohexstr(l.password_hash) AS PassHashLocal,
    r.Is_Disabled AS DisabledRemoute,
    l.is_disabled AS DisabledLocal,
    r.Modify_Date AS Modify_DateRemoute,
    MAX(r.Modify_Date) OVER (PARTITION BY l.name) AS MAXModify_DateRemoute,
    l.modify_date AS Modify_DateLocal,
    l.is_policy_checked AS Is_Policy_CheckedLocal,
    l.is_expiration_checked AS Is_Expiration_CheckedLocal,
    r.is_policy_checked AS Is_Policy_CheckedRemote,
    r.is_expiration_checked AS Is_Expiration_CheckedRemote,
    r.ServerName AS ServerNameRemoute,
    @@SERVERNAME AS ServerNameLocal
FROM #LoginsRemote r
LEFT JOIN sys.sql_logins l
    ON l.name = r.Login;

SELECT 'LoginsComparison' AS LoginsComparison, * FROM #LoginsComparison;

-------------------------------------------------------

-- Шаг 1: Обновление PasswordHash и параметров политики
IF @stepdId IN (0,1)
BEGIN
    -- Вставка логинов, требующих обновления пароля и политик
    CREATE TABLE #Step1 (
        LoginLocal NVARCHAR(255),
        PassHashRemoute NVARCHAR(500),
        Is_Policy_CheckedRemote BIT,
        Is_Expiration_CheckedRemote BIT,
        MAXModify_DateRemoute DATETIME
    );

    INSERT INTO #Step1 (LoginLocal, PassHashRemoute, Is_Policy_CheckedRemote, Is_Expiration_CheckedRemote, MAXModify_DateRemoute)
    SELECT
        LoginLocal,
        PassHashRemoute,
        Is_Policy_CheckedRemote,
        Is_Expiration_CheckedRemote,
        MAXModify_DateRemoute
    FROM #LoginsComparison
    WHERE (PassHashLocal != PassHashRemoute or Is_Policy_CheckedLocal !=Is_Policy_CheckedRemote or Is_Expiration_CheckedLocal!=Is_Expiration_CheckedRemote)
      AND Modify_DateLocal < Modify_DateRemoute
      AND Modify_DateRemoute = MAXModify_DateRemoute;

SELECT 'Step1' AS Step1, * FROM #Step1;

    -- Цикл обработки каждой записи в #Step1
    WHILE EXISTS (SELECT 1 FROM #Step1)
    BEGIN
        -- Выборка одной записи для обработки
        SELECT TOP 1
            @LoginLocal = LoginLocal,
            @PassHashRemoute = PassHashRemoute,
            @is_policy_checked = Is_Policy_CheckedRemote,
            @is_expiration_checked = Is_Expiration_CheckedRemote,
            @MAXmodify_dateRemoute = MAXModify_DateRemoute
        FROM #Step1;

        -- Обновление логина с учетом политик

            -- Преобразование битовых значений в ON/OFF
        set @check_exp  = CASE WHEN  @is_expiration_checked = 1 THEN 'ON' ELSE 'OFF' END;
        set @check_pol = CASE WHEN @is_policy_checked = 1 THEN 'ON' ELSE 'OFF' END;

            -- Обновление других свойств логина с учетом политик
            SET @cmd = 'ALTER LOGIN [' + @LoginLocal + '] WITH CHECK_EXPIRATION = off,CHECK_POLICY = OFF;
                        ALTER LOGIN [' + @LoginLocal + '] WITH PASSWORD = ' + @PassHashRemoute + ' HASHED;
                        ALTER LOGIN [' + @LoginLocal + '] WITH  CHECK_EXPIRATION = ' + @check_exp + ', CHECK_POLICY = ' + @check_pol + ';';
            PRINT @cmd;
            IF @debug = 0 EXEC (@cmd);

        -- Удаление обработанной строки из #Step1
        DELETE FROM #Step1
        WHERE LoginLocal = @LoginLocal
    END

    DROP TABLE #Step1;
END

-------------------------------------------------------

-- Шаг 2: Обновление состояния логинов (включен/отключен)
IF @stepdId IN (0,2)
BEGIN
    -- Вставка логинов, требующих обновления состояния
    CREATE TABLE #Step2 (
        LoginLocal NVARCHAR(255),
        DisabledRemoute BIT
    );

    INSERT INTO #Step2 (LoginLocal, DisabledRemoute)
    SELECT
        LoginLocal,
        DisabledRemoute
    FROM #LoginsComparison
    WHERE DisabledRemoute != DisabledLocal
      AND Modify_DateLocal < Modify_DateRemoute;

SELECT 'Step2' as Step2, * FROM #Step2;

    -- Цикл обработки каждой записи в #Step2
    WHILE EXISTS (SELECT 1 FROM #Step2)
    BEGIN
        -- Выборка одной записи для обработки
        SELECT TOP 1
            @LoginLocal = LoginLocal,
            @DisabledRemoute = DisabledRemoute
        FROM #Step2;

        -- Обновление состояния логина
        IF @DisabledRemoute = 1
            SET @cmd = 'ALTER LOGIN [' + @LoginLocal + '] DISABLE;';
        ELSE
            SET @cmd = 'ALTER LOGIN [' + @LoginLocal + '] ENABLE;';
        PRINT @cmd;
        IF @debug = 0 EXEC (@cmd);

        -- Удаление обработанной строки из #Step2
        DELETE FROM #Step2
        WHERE LoginLocal = @LoginLocal
          AND DisabledRemoute = @DisabledRemoute;
    END
    DROP TABLE #Step2;
END

-------------------------------------------------------

-- Шаг 3: Создание новых логинов
IF @stepdId IN (0,3)
BEGIN
    -- Вставка логинов, которых нет локально и их необходимо создать
    CREATE TABLE #Step3 (
        LoginRemoute NVARCHAR(255),
        PassHashRemoute NVARCHAR(500),
        SidRemoute NVARCHAR(500),
        Is_Policy_CheckedLocal BIT,
        Is_Expiration_CheckedLocal BIT
    );

    INSERT INTO #Step3 (LoginRemoute, PassHashRemoute, SidRemoute, Is_Policy_CheckedLocal, Is_Expiration_CheckedLocal)
    SELECT DISTINCT
        LoginRemoute,
        PassHashRemoute,
        SidRemoute,
        Is_Policy_CheckedLocal,
        Is_Expiration_CheckedLocal
    FROM #LoginsComparison
    WHERE LoginLocal IS NULL;
 
    SELECT 'Step3' AS Step3, * FROM #Step3;

    -- Цикл обработки каждой записи в #Step3
    WHILE EXISTS (SELECT 1 FROM #Step3)
    BEGIN
        -- Выборка одной записи для обработки
        SELECT TOP 1
            @LoginRemoute = LoginRemoute,
            @PassHashRemoute = PassHashRemoute,
            @sidremote = SidRemoute,
            @is_policy_checked = Is_Policy_CheckedLocal,
            @is_expiration_checked = Is_Expiration_CheckedLocal
        FROM #Step3;

        -- Преобразование битовых значений в ON/OFF для CHECK_POLICY и CHECK_EXPIRATION
        set @check_exp  = CASE WHEN  @is_expiration_checked = 1 THEN 'ON' ELSE 'OFF' END;
        set  @check_pol = CASE WHEN @is_policy_checked = 1 THEN 'ON' ELSE 'OFF' END;

        -- Формирование команды создания логина с учетом политик
        SET @cmd = 'CREATE LOGIN [' + @LoginRemoute + ']
                    WITH PASSWORD = ' + @PassHashRemoute + ' HASHED,
                         SID = ' + @sidremote + ',
                         DEFAULT_DATABASE = [master],
                         DEFAULT_LANGUAGE = [us_english],
                         CHECK_EXPIRATION = ' + @check_exp + ',
                         CHECK_POLICY = ' + @check_pol + ';';
        PRINT @cmd;
        IF @debug = 0 EXEC (@cmd);

        -- Удаление обработанной строки из #Step3
        DELETE FROM #Step3
        WHERE LoginRemoute = @LoginRemoute;
    END

    DROP TABLE #Step3;
END

-- Очистка временных таблиц
-- DROP TABLE #LoginsRemote;
-- DROP TABLE #LoginsComparison;
-- DROP TABLE #NodeAG; 
