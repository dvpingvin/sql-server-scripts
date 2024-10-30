/****************************************************************************/
/*         SQL Server Advanced Troubleshooting and Performance Tuning       */
/*         O'Reilly, 2022. ISBN-13: 978-1098101923 ISBN-10: 1098101928      */
/*                                                                          */
/*                  Written by Dmitri V. Korotkevitch                       */
/*                      https://aboutsqlserver.com                          */
/*                        dk@aboutsqlserver.com                             */
/****************************************************************************/
/* Не оставлять включенными! Использовать только для устрания неполадок!    */
/* Захватывает инструкции, которые потребляют более 5000 мс времени ЦПУ     */
/* или производят более 50 000 логических операций чтения/записи.           */
/* Этот код работает в версиях SQL Server начиная с 2012.                    */
/****************************************************************************/

CREATE EVENT SESSION [Expensive Queries]
ON SERVER
ADD EVENT sqlserver.sql_statement_completed
(
ACTION
(
sqlserver.client_app_name
,sqlserver.client_hostname
,sqlserver.database_id
,sqlserver.plan_handle
,sqlserver.query_hash
,sqlserver.query_plan_hash
,sqlserver.sql_text
,sqlserver.username
)
WHERE
(
(
cpu_time >= 5000000 or -- Время в микросекундах
logical_reads >= 50000 or
writes >= 50000
) AND
sqlserver.is_system = 0
)
)
,ADD EVENT sqlserver.sp_statement_completed
(
ACTION
(
sqlserver.client_app_name
,sqlserver.client_hostname
,sqlserver.database_id
,sqlserver.plan_handle
,sqlserver.query_hash
,sqlserver.query_plan_hash
,sqlserver.sql_text
,sqlserver.username
)
WHERE
(
(
cpu_time >= 5000000 or -- Время в микросекундах
logical_reads >= 50000 or
writes >= 50000
) AND
sqlserver.is_system = 0
)
)
ADD TARGET package0.event_file
(
SET FILENAME = 'C:\ExtEvents\Expensive Queries.xel'
)
WITH
(
event_retention_mode=allow_single_event_loss
,max_dispatch_latency=30 seconds
);
