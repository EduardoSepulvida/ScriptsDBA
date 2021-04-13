USE tempdb
 
SELECT
 ssu.session_id,
 (ssu.internal_objects_alloc_page_count + sess_alloc) AS allocated,
 (ssu.internal_objects_dealloc_page_count + sess_dealloc) AS deallocated,
 stm.TEXT
FROM sys.dm_db_session_space_usage AS ssu,
 sys.dm_exec_requests req
 CROSS APPLY sys.dm_exec_sql_text(sql_handle) AS stm,
 (SELECT
 session_id,
 SUM(internal_objects_alloc_page_count) AS sess_alloc,
 SUM(internal_objects_dealloc_page_count) AS sess_dealloc
 FROM sys.dm_db_task_space_usage
 GROUP BY session_id) AS tsk
WHERE ssu.session_id = tsk.session_id
AND ssu.session_id > 50
AND ssu.session_id = req.session_id
AND ssu.database_id = 2
ORDER BY allocated DESC


=================================

SELECT A.session_id,B.host_name, B.Login_Name ,
(user_objects_alloc_page_count + internal_objects_alloc_page_count)*1.0/128 as TotalalocadoMB,
D.Text
FROM sys.dm_db_session_space_usage A
JOIN sys.dm_exec_sessions B  ON A.session_id = B.session_id
JOIN sys.dm_exec_connections C ON C.session_id = B.session_id
CROSS APPLY sys.dm_exec_sql_text(C.most_recent_sql_handle) As D
WHERE A.session_id > 50
and (user_objects_alloc_page_count + internal_objects_alloc_page_count)*1.0/128 > 100 -- Ocupam mais de 100 MB
ORDER BY totalalocadoMB desc
--------------------------------------------------------------


https://suporte.powertuning.com.br/kb/pt-br/article/136456/tempdb-identificando-consumidores-de-espaco
Tempdb: Identificando consumidores de espaço
8 min
Criado por: Rodrigo Ribeiro Gomes em: 14/08/2020 19:16
Geralmente, em 99% dos casos, o consumo de espaço da tempdb vai vir de um desses três lugares:
 

Sessões
Objetos internos
Objetos de usuário ( sessões criadno tabelas temporárias, etc.)
Version Store
Log 
 

Felizmente, existem DMVs que podem nos indicar quem está gastando. Este artigo traz orientações gerais de como identificar quem está consumindo da tempdb.
 

Primeiro, confirme o quanto está em uso nos arquivos. Esta query traz o consumo por arquivo e no final o total: 

USE tempdb; 

SELECT
       file_id
       ,name
       ,type_desc
       ,TamMB = SUM(size/128)
       ,UsedMB = SUM(FILEPROPERTY(name,'SpaceUsed')/128)
       ,PercUsed = SUM(FILEPROPERTY(name,'SpaceUsed'))*100./SUM(size)
FROM
       sys.database_files
GROUP BY
       GROUPING SETS (
             (file_id,name,type_desc)
             ,()
       )
 

Ela é util para que você identifique e confirme se reallmente há um consumo alto da tempdb e em quantos % este consumo está. 

Após confirmar que os arquivos estão realmente com um alto percentual de consumo, tente identificar de onde vem com esse script:
 

SELECT
       *
       ,TotalTempdb = SessionsUsage + LogUsed + VersionStoredUsed
FROM
(
       SELECT
              SessionsUsage =  SUM(ISNULL(CONVERT(decimal(15,2),(a-d)/128.00),0))     
       FROM
             (
                    SELECT
                            a = TU.internal_objects_alloc_page_count+TU.user_objects_alloc_page_count
                           ,d = TU.internal_objects_dealloc_page_count+TU.user_objects_dealloc_page_count
                    FROM
                           sys.dm_db_task_space_usage TU
                    WHERE
                           TU.session_id IN (SELECT R.session_id FROM sys.dm_exec_requests R)

                    UNION ALL                  

                    SELECT
                            SU.internal_objects_alloc_page_count+SU.user_objects_alloc_page_count
                           ,SU.internal_objects_dealloc_page_count+SU.user_objects_dealloc_page_count
                    FROM
                           sys.dm_db_session_space_usage SU
                    WHERE
                           SU.session_id IN ( SELECT S.session_id FROM sys.dm_exec_sessions S WHERE S.status = 'sleeping' )
             ) SU
       WHERE
             a >= d
) D
CROSS JOIN
(
             SELECT
                    LogUsed = ISNULL(SUM(DT.database_transaction_log_bytes_reserved)/1024./1024,0)

             FROM

             sys.dm_tran_database_transactions DT

             INNER JOIN

             sys.dm_tran_session_transactions ST

                    ON DT.transaction_id = ST.transaction_id

             WHERE

                    DT.database_id = 2

) L

CROSS JOIN

(

             SELECT

                    VersionStoredUsed = ISNULL(SUM(reserved_space_kb)/1024.,0)

             FROM

                    sys.dm_tran_version_store_space_usage

) VS

 

 

Ele irá retornar essas colunas:

 

SessionUsage
Total em MB usados pelas sessões.

LogUsed
Total em MB usado pelo log

VersionStoreUsed
Total em MB usado pela verson store

TotalTempdb
Soma das outras três, repesentando o total usado pela tempdb. Este valor deverá ser próximo do valor anterior
 

A seguir, alguns scripts úteis para usar dependendo de qual das três colunas acima.

 

SessionUsage e LogUsed

Estes valores indicam que o maior consumo vem de alguma sessão, geralmente uma tabela temporária criada ou algum sort. Para identificar qual sessão está mais alocando espaço, utilize esse script:

 

SELECT

       *

FROM

(

       SELECT

             SU.session_id

             ,InternalUsed = ISNULL(CONVERT(decimal(15,2),SU.internal_objects_alloc_page_count - SU.internal_objects_dealloc_page_count),0)

             ,TotalDataUsed =  ISNULL(CONVERT(decimal(15,2),(     

                    (SU.internal_objects_alloc_page_count+SU.user_objects_alloc_page_count)

                           -

                    (SU.internal_objects_dealloc_page_count+SU.user_objects_dealloc_page_count)

             )/128.00),0) 

             ,TotalPeak    =  ISNULL(CONVERT(decimal(15,2),(SU.internal_objects_alloc_page_count+SU.user_objects_alloc_page_count)/128.00             ),0)

             ,LogUsed      =  ISNULL(CONVERT(decimal(15,2),L.Qtdlog/1024.00/1024.00),0)

       FROM

             sys.dm_Exec_sessions S

             LEFT JOIN

             (

                    SELECT

                           TU.session_id

                           ,SUM(TU.internal_objects_alloc_page_count)            internal_objects_alloc_page_count

                           ,SUM(TU.user_objects_alloc_page_count)                user_objects_alloc_page_count

                           ,SUM(TU.internal_objects_dealloc_page_count)       internal_objects_dealloc_page_count

                           ,SUM(TU.user_objects_dealloc_page_count)        user_objects_dealloc_page_count

                    FROM

                           sys.dm_db_task_space_usage TU

                    WHERE

                           TU.session_id IN (SELECT R.session_id FROM sys.dm_exec_requests R)

                    GROUP BY

                           TU.session_id

                   

                    UNION ALL

                   

                    SELECT

                                  SU.session_id

                           ,SU.internal_objects_alloc_page_count

                           ,SU.user_objects_alloc_page_count

                           ,SU.internal_objects_dealloc_page_count

                           ,SU.user_objects_dealloc_page_count

                    FROM

                           sys.dm_db_session_space_usage SU

                    WHERE

                           SU.session_id IN ( SELECT S.session_id FROM sys.dm_exec_sessions S WHERE S.status = 'sleeping' )

 

             ) SU

                    ON SU.session_id = S.session_id

             OUTER APPLY

             (

                           SELECT

                                  QtdLog = DT.database_transaction_log_bytes_reserved

                           FROM

                           sys.dm_tran_database_transactions DT

                           INNER JOIN

                           sys.dm_tran_session_transactions ST

                                  ON DT.transaction_id = ST.transaction_id

                           WHERE

                                  DT.database_id = 2

                                  AND

                                  ST.session_id = S.session_id

             ) L

) TU

WHERE

       TU.TotalDataUsed + TU.LogUsed > 0

 

 

As colunas retornadas são:

session_id
Id da sessão
InternalUsed
Total em MB alocados por algum componente interno da query (não controlado pelo usuário) como um sort, por exemplo
TotalDataUsage
Total em MB, incluindo interno e alocaods pelo usuário, que foi usado. 
TotalPeak
O máximmo usado até agora, mas não necessariamente o atual. Em MB.
LogUsed
Total de log usado pela sessão em MB

 

VersionStore
No caso da version store, você precisa identificar qual transação está segurando as versões na tempdb e entender o porque ela não está sendo fechada.

O script abaixo traz os TOP 5 bancos com mais versões criadas na tempdb. No segundo resultado ele traz todas as transações abertas que dependem de alguma versão, ordenada pela id interno usado na version store. Com isso, voc~e pode procurar mais informações sobre estas sessões para saber o porquê essas transações estão demorando serem encerradas.

SELECT TOP 5

       DB_NAME(database_id)

       ,UsedMB = reserved_space_kb/128.0

FROM

       sys.dm_tran_version_store_space_usage

ORDER BY

       UsedMB desc

 

SELECT

        S.session_id

       ,T.transaction_id

       ,T.transaction_begin_time 

       ,T.transaction_begin_time

       ,Elapsed = DATEDIFF(SS,T.transaction_begin_time,GETDATE())

       ,Db = DB_NAME(D.database_id)

       ,D.database_transaction_log_bytes_used

       ,SN.transaction_sequence_num

       ,SN.first_snapshot_sequence_num

       ,SN.average_version_chain_traversed

       ,SN.is_snapshot

FROM

       sys.dm_tran_active_transactions         T

       JOIN

       sys.dm_tran_session_transactions  S

             ON S.transaction_id = T.transaction_id

       JOIN

       sys.dm_tran_database_transactions D    

             ON D.transaction_id = T.transaction_id

       LEFT JOIN

       sys.dm_tran_active_snapshot_database_transactions SN

             ON SN.transaction_id  = T.transaction_id

WHERE

       transaction_sequence_num IS NOT NULL

ORDER BY    

       SN.transaction_sequence_num

 

 

 

 

 

 

USE tempdb; SELECTfile_id,name,type_desc,TamMB = SUM(size/128),UsedMB = SUM(FILEPROPERTY(name,'SpaceUsed')/128),PercUsed = SUM(FILEPROPERTY(name,'SpaceUsed'))*100./SUM(size)FROMtempdb.sys.database_filesGROUP BYGROUPING SETS ((file_id,name,type_desc),()) SELECT*,TotalTempdb = SessionsUsage + LogUsed + VersionStoredUsedFROM(SELECT SessionsUsage =  SUM(ISNULL(CONVERT(decimal(15,2),(a-d)/128.00),0))FROM(SELECT a = TU.internal_objects_alloc_page_count+TU.user_objects_alloc_page_count,d = TU.internal_objects_dealloc_page_count+TU.user_objects_dealloc_page_countFROMsys.dm_db_task_space_usage TUWHERETU.session_id IN (SELECT R.session_id FROM sys.dm_exec_requests R)  UNION ALL SELECT SU.internal_objects_alloc_page_count+SU.user_objects_alloc_page_count,SU.internal_objects_dealloc_page_count+SU.user_objects_dealloc_page_countFROMsys.dm_db_session_space_usage SUWHERESU.session_id IN ( SELECT S.session_id FROM sys.dm_exec_sessions S WHERE S.status = 'sleeping' ) ) SUWHEREa >= d) DCROSS JOIN(SELECTLogUsed = ISNULL(SUM(DT.database_transaction_log_bytes_reserved)/1024./1024,0)FROMsys.dm_tran_database_transactions DTINNER JOINsys.dm_tran_session_transactions STON DT.transaction_id = ST.transaction_idWHEREDT.database_id = 2) LCROSS JOIN(SELECTVersionStoredUsed = ISNULL(SUM(reserved_space_kb)/1024.,0)FROMsys.dm_tran_version_store_space_usage) VS
