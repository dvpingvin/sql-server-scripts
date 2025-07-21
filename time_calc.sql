DECLARE @StartDate DATETIME = '2025-07-19 17:48:58';
DECLARE @Duration TIME = '06:52:51';

--Прибавляем часы, минуты и секунды по отдельности
SELECT DATEADD(SECOND, DATEPART(SECOND, @Duration),
DATEADD(MINUTE, DATEPART(MINUTE, @Duration),
DATEADD(HOUR, DATEPART(HOUR, @Duration), @StartDate))) AS ResultDateTime;
