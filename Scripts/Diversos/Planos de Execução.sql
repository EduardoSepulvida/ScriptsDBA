-- retorna todos os planos em cache
SELECT cp.objtype AS PlanType,
 OBJECT_NAME(st.objectid,st.dbid) AS ObjectName,
 cp.refcounts AS ReferenceCounts,
 cp.usecounts AS UseCounts,
 st.text AS SQLBatch,
 qp.query_plan AS QueryPlan
FROM sys.dm_exec_cached_plans AS cp
CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) AS qp
CROSS APPLY sys.dm_exec_sql_text(cp.plan_handle) AS st
--where st.text like '%vt1090%'

--retorna os planos em cache das consultas em exec.
SELECT QP.query_plan as [Query Plan], 
       ST.text AS [Query Text]
FROM sys.dm_exec_requests AS R
   CROSS APPLY sys.dm_exec_query_plan(R.plan_handle) AS QP
   CROSS APPLY sys.dm_exec_sql_text(R.plan_handle) ST
   WHERE  ST.text like '%vt1090%'


SELECT plan_handle, st.text  
FROM sys.dm_exec_cached_plans   
CROSS APPLY sys.dm_exec_sql_text(plan_handle) AS st  
WHERE text LIKE N'%busca%';


select * from sys.dm_exec_query_plan(0x0600180052E4CE0EC0B078F07B00000001000000000000000000000000000000000000000000000000000000)


