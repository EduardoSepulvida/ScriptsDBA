USE [StackOverflow2010]
GO

CREATE TABLE CT_Teste (
	ID INT IDENTITY(1,1) PRIMARY KEY
	,NOME VARCHAR(250)
	,DATA_NASCIMENTO DATE
)

INSERT INTO CT_Teste
VALUES
	('Eduardo Rabelo','1996-07-30')
	,('Felipe Rabelo','1998-08-24')
	,('Yago Rabelo','1996-05-09')

SELECT * FROM CT_Teste



--HABILITANDO O CHANGE_TRACKING DATABASE
ALTER DATABASE [StackOverflow2010]  
SET CHANGE_TRACKING = ON  
(CHANGE_RETENTION = 1 DAYS, AUTO_CLEANUP = ON)  

--HABILITANDO CT NA TABELA
ALTER TABLE [CT_Teste]
ENABLE CHANGE_TRACKING  
WITH (TRACK_COLUMNS_UPDATED = ON)


--DESABILITANDO CT NA TABELA
ALTER TABLE [CT_Teste] 
DISABLE CHANGE_TRACKING;  

--DESABILITANDO CT NA TABELA
ALTER DATABASE [StackOverflow2010]  
SET CHANGE_TRACKING = OFF  



-----------------------------------------------------------------------------
SELECT * FROM CT_Teste

UPDATE CT_Teste SET NOME = 'Eduardo' WHERE ID = 1

SELECT * FROM CT_Teste

UPDATE CT_Teste SET NOME = 'Eduardo Rabelo' WHERE ID = 1

SELECT * FROM CT_Teste

UPDATE CT_Teste SET NOME = 'Eduardo Rabelo Sepulvida' WHERE ID = 1

SELECT * FROM CT_Teste

UPDATE CT_Teste SET NOME = 'ERS' WHERE ID = 1

SELECT * FROM CT_Teste

INSERT INTO CT_Teste VALUES ('Sidney','1970-01-23')

SELECT * FROM CT_Teste

UPDATE CT_Teste SET NOME = 'YAGO', DATA_NASCIMENTO='1990-01-01'  WHERE ID = 2

SELECT * FROM CT_Teste

DELETE CT_Teste  WHERE ID = 3
INSERT INTO CT_Teste VALUES ('Alguem','1991-11-11')
INSERT INTO CT_Teste VALUES ('Quem','1999-05-05')

SELECT * FROM CT_Teste


---------------------------------------------------------------
declare @last_synchronization_version bigint;

SET @synchronization_version = CHANGE_TRACKING_CURRENT_VERSION();  

SELECT  
    CT.ID, CT.SYS_CHANGE_OPERATION,  
    CT.SYS_CHANGE_COLUMNS, CT.SYS_CHANGE_CONTEXT  
FROM  
    CHANGETABLE(CHANGES [CT_Teste], @last_synchronization_version) AS CT



declare @last_synchronization_version bigint;

	SELECT  
    CT.ID, P.NOME, P.DATA_NASCIMENTO,  
    CT.SYS_CHANGE_OPERATION, CT.SYS_CHANGE_COLUMNS,  
    CT.SYS_CHANGE_CONTEXT, CT.SYS_CHANGE_VERSION
	,tc.commit_time
FROM  
    [CT_Teste] AS P  
RIGHT OUTER JOIN  
    CHANGETABLE(CHANGES [CT_Teste], @last_synchronization_version) AS CT  
ON  
    P.ID = CT.ID  
JOIN 
	sys.dm_tran_commit_table tc 
ON 
	cT.sys_change_version = tc.commit_ts


----------------------------------------------------------------------------------

SELECT db.name,ct.* FROM sys.change_tracking_databases ct JOIN sys.databases db ON db.database_id = ct.database_id


select @@SERVERNAME AS server_name,
sct2.name as schema_name,
sot2.name as table_name,
SUM(ps2.row_count) as table_rows,
(SUM(ps2.reserved_page_count)*8024)/1024/1024 as table_size_mb,
MAX(CAST(ctt.is_track_columns_updated_on AS TINYINT)) AS ct_enabled,
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

