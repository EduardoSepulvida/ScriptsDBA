select
ST.transaction_id
,database_transaction_begin_time
,KBUsed = database_transaction_log_bytes_used/1024
,LogCount = database_transaction_log_record_count
,t.name
,t.transaction_begin_time, st.session_id
from sys.dm_tran_database_transactions DT
JOIN
sys.dm_tran_session_transactions ST
ON ST.transaction_id = DT.transaction_id
join
sys.dm_tran_active_transactions t
on t.transaction_id = st.transaction_id