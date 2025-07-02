SELECT
object_name,
counter_name,
instance_name,
CASE counter_type
WHEN 65792 THEN 'PERF_COUNTER_RAWCOUNT (Простое целочисленное значение)'
WHEN 537003264 THEN 'PERF_COUNTER_LARGE_RAWCOUNT (64-битное целочисленное значение)'
WHEN 272696320 THEN 'PERF_COUNTER_BULK_COUNT (Количество событий в секунду)'
WHEN 272696576 THEN 'PERF_AVERAGE_BULK (Среднее значение на операцию)'
WHEN 1073874176 THEN 'PERF_COUNTER_COUNTER (Частота событий в секунду)'
WHEN 1073939712 THEN 'PERF_100NSEC_TIMER (Время выполнения в 100-наносекундных интервалах)'
ELSE 'Неизвестный тип: ' + CAST(counter_type AS VARCHAR)
END AS counter_type_description,
cntr_value AS counter_value
FROM
sys.dm_os_performance_counters;
/*
Типы счётчиков в sys.dm_os_performance_counters:

65792 (0x00010100) - PERF_COUNTER_RAWCOUNT
Простое целочисленное значение (сырой счётчик)
Хранит текущее значение без расчётов
Пример: количество активных соединений

537003264 (0x20020400) - PERF_COUNTER_LARGE_RAWCOUNT
Аналог RAWCOUNT, но поддерживает 64-битные значения
Используется для больших чисел (например, общее количество запросов)

272696320 (0x10410500) - PERF_COUNTER_BULK_COUNT
Счётчик, измеряющий количество событий в секунду
Использует два замера для расчёта разницы во времени
Пример: "Transactions/sec"

272696576 (0x10410700) - PERF_AVERAGE_BULK
Среднее значение на операцию
Пример: "Average Latch Wait Time (ms)"
Формула: TotalValue / TotalOperations

1073874176 (0x40000200) - PERF_COUNTER_COUNTER
Показывает количество событий в секунду
Измеряет частоту событий (например, "Deadlocks/sec")
Использует два замера для вычисления разницы во времени

1073939712 (0x40010500) - PERF_100NSEC_TIMER
Счётчик времени выполнения в 100-наносекундных интервалах
Показывает, какую долю времени процесс занят
Пример: "Процент времени CPU"
Формула: (CurrentValue - PreviousValue) / (CurrentTime100ns - PreviousTime100ns) * 100
*/
