--Clean up the plans for a database
DBCC FLUSHPROCINDB (8) -- 8 is the databaseid of Dec_ProdStats
GO
--Check the count of the plans
Select dbid,db_name(dbid),count(1) From sys.dm_exec_cached_plans dec
CROSS APPLY sys.dm_exec_sql_text(dec.plan_handle) AS des
where db_name(dbid) in ('Nov_ProdStats','Dec_ProdStats') --Sample Databases for the demonstration
Group by db_name(dbid), dbid