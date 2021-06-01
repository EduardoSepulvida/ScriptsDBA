--1º PASSO - HABILITAR O CHANGE_TRACKING NA BASE:

--HABILITANDO O CHANGE_TRACKING NA BASE
ALTER DATABASE [DATABASE_NAME]  
SET CHANGE_TRACKING = ON  
(CHANGE_RETENTION = 2 DAYS, AUTO_CLEANUP = ON)  

-- COM ESSAS OPÇÕES TEREMOS 2 HISTÓRICO DE 2 DIAS DE ALTERAÇÕES, E O SQL SERVER IRÁ LIMPAR AUTOMATICAMENTE


--VERIFICANDO SE FOI HABILITADO NA BASE:
SELECT db.name,ct.* FROM sys.change_tracking_databases ct JOIN sys.databases db ON db.database_id = ct.database_id


--2º PASSO - HABILITAR O CHANGE_TRACKING NAS TABELAS

--HABILITANDO CT NA TABELA
ALTER TABLE [TABLE_NAME]
ENABLE CHANGE_TRACKING  


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


--3º PASSO - ACOMPANHAR AS ALTERAÇÕES
-- NESTE PASSO PODEMOS CRIAR UMA VIEW PARA VER AS MUDANÇAS, OU UMA PROCEDURE PARA PERSISTIR AS MUDANÇAS EM TABELA, TUDO DE ACORDO COM A REGRA DE NEGÓCIO

--EX. VIEW:
--BASTA ALTERAR O NOME DA TABELA DA TABELA NO FROM E NO JOIN

CREATE VIEW TABELA_CHANGE_TRACKING
AS  
 SELECT    
   CT.R_E_C_N_O_  
   ,CT.SYS_CHANGE_OPERATION AS TIPO_ALTERACAO  
   , CONVERT(datetime, SWITCHOFFSET(CONVERT(datetimeoffset, tc.commit_time), DATENAME(TzOffset, SYSDATETIMEOFFSET()))) AS DATA_ALTERACAO  
  FROM    
   [BASE]..[TABELA] AS P    
  RIGHT OUTER JOIN    
   CHANGETABLE(CHANGES [BASE]..[TABELA], 0) AS CT    
  ON    
   P.R_E_C_N_O_ = CT.R_E_C_N_O_    
  JOIN   
   sys.dm_tran_commit_table tc   
  ON   
   CT.SYS_CHANGE_VERSION = tc.commit_ts
   
   
 
   
/*   
COM ESSE MONITORAMENTO TEMOS A PK, TIPO DE ALTERAÇÃO E DATA QUE FOI COMITADO A ALTERAÇÃO NO BANCO

PARA PEGAR A COLUNA QUE FOI MODIFICADA PRECISAMOS PARTIR PARA UMA OUTRA FORMA DE HABILITAR O TRACK_COLUMNS_UPDATED NA TABELA, PORÉM É UM PROCESSO QUE VAI CONSUMIR MAIS RECURSOS POIS PRECISA TRATAR COLUNA A COLUNA, ALÉM DE QUE PRECISA DE UMA VIEW MAIS COMPLEXA PARA CONSEGUIR CONSULTAS AS ALTERAÇÕES

--HABILITANDO TRACK_COLUMNS_UPDATED NA TABELA
ALTER TABLE [CT_Teste]
ENABLE CHANGE_TRACKING  
WITH (TRACK_COLUMNS_UPDATED = ON)
 */ 
   
   
   
 -- PARA DESABILITAR O CT NA BASE, PRIMEIRO PRECISAMOS DESABILITAR EM TODAS AS TABELAS DO BANCO:  

--DESABILITANDO CT NA TABELA
ALTER TABLE [TABLE_NAME] 
DISABLE CHANGE_TRACKING;  

--DESABILITANDO CT NA BASE
ALTER DATABASE [DATABASE_NAME]  
SET CHANGE_TRACKING = OFF  


--https://sirsql.net/tag/spflushcommittableondemand/