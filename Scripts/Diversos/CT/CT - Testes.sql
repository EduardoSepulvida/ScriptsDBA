
SELECT CHANGE_TRACKING_CURRENT_VERSION(); 
20134

select * from CT_Teste

insert into CT_Teste(NOME, DATA_NASCIMENTO) 
VALUES	('EDUARDO','19960730')
		,('FELIPE','19980828')
GO 10

SELECT CHANGE_TRACKING_CURRENT_VERSION(); 
20135


DELETE top(1) FROM CT_Teste

SELECT CHANGE_TRACKING_CURRENT_VERSION(); 
20136

UPDATE CT_Teste SET NOME = 'm' where id = 49

20138

20148
--SCRIPT PARA CONFERIR TABELAS COM CT HABILITADO:
select @@SERVERNAME AS server_name,
sct2.name as schema_name,
sot2.name as table_name,
SUM(ps2.row_count) as table_rows,
(SUM(ps2.reserved_page_count)*8024)/1024/1024 as table_size_mb,
MAX(CAST(ctt.is_track_columns_updated_on AS TINYINT)) AS is_track_columns_updated_on,
MAX(ps1.row_count) as ct_rows,
(MAX(ps1.reserved_page_count)*8024)/1024/1024 as ct_size_mb,
MAX(ctt.cleanup_version) AS ct_cleanup_ver, /*cleanup may have removed data up to this version */
MAX(ctt.min_valid_version) AS ct_minimum_ver /*syncing applications should only expect data on or after this version */ 
FROM sys.internal_tables it
JOIN sys.objects sot1 on it.object_id=sot1.object_id
JOIN sys.schemas AS sct1 ON sot1.schema_id=sct1.schema_id
JOIN sys.dm_db_partition_stats ps1 ON it.object_id = ps1. object_id AND ps1.index_id in (0,1)
LEFT JOIN sys.objects sot2 on it.parent_object_id=sot2.object_id
JOIN sys.change_tracking_tables AS ctt ON ctt.object_id = sot2.object_id
LEFT JOIN sys.schemas AS sct2 ON sot2.schema_id=sct2.schema_id
LEFT JOIN sys.dm_db_partition_stats ps2 ON sot2.object_id = ps2. object_id AND ps2.index_id in (0,1)
WHERE it.internal_type IN (209, 210)
GROUP BY sct2.name, sot2.name
ORDER BY sct2.name, sot2.name;

SELECT * FROM SYS.VIEWS
DECLARE @Context varbinary(128) = CAST('1 - UPDATE' AS varbinary(128));
 
WITH CHANGE_TRACKING_CONTEXT (@Context) 
 UPDATE TOP(1) CT_Teste SET NOME = 'EDUARDO'

select *,CAST(ct.SYS_CHANGE_CONTEXT as varchar(255))  From CHANGETABLE(CHANGES StackOverflow2010..CT_Teste, 0) AS CT   


SELECT TOP 10 * FROM sys.dm_tran_commit_table



 SELECT    
   CT.id  
   ,CT.SYS_CHANGE_OPERATION AS TIPO_ALTERACAO  
   , CONVERT(datetime, SWITCHOFFSET(CONVERT(datetimeoffset, tc.commit_time), DATENAME(TzOffset, SYSDATETIMEOFFSET()))) AS DATA_ALTERACAO  
  FROM    
   StackOverflow2010..CT_Teste AS P    
  RIGHT OUTER JOIN    
   CHANGETABLE(CHANGES StackOverflow2010..CT_Teste, 0) AS CT    
  ON    
   P.id = CT.id    
  JOIN   
   sys.dm_tran_commit_table tc   
  ON   
   CT.SYS_CHANGE_VERSION = tc.commit_ts
   


   ALTER TABLE CT_Teste
ENABLE CHANGE_TRACKING  

create table tb3 (c1 int, c2 int)

insert into tb3 values(1,2)

select * from tb3


alter table tb3 add id bigint identity

