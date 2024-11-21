select count(*) from sys.dm_tran_active_transactions

select top 30 * from sys.dm_tran_active_transactions
where transaction_type !=2
order by transaction_begin_time