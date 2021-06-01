

-- VERIFICA QUAIS BANCOS TEM CT
IF OBJECT_ID('Traces..ct_databases_controll') IS NOT NULL
DROP TABLE Traces..ct_databases_controll

CREATE TABLE Traces..ct_databases_controll(
	name sysname
)


INSERT INTO Traces..ct_databases_controll
SELECT DISTINCT db.name FROM sys.change_tracking_databases ct JOIN sys.databases db ON db.database_id = ct.database_id WHERE db.name NOT IN (SELECT db.name FROM Traces..ct_databases_controll)


-- VERIFICA QUAIS TABELAS TEM CT
IF OBJECT_ID('Traces..ct_tables_controll') IS NOT NULL
DROP TABLE Traces..ct_tables_controll

CREATE TABLE Traces..ct_tables_controll(
	database_name sysname
	,schema_name sysname	
	,table_name sysname
	,object_hash varbinary(8000) 
)

EXEC sp_MSforeachdb 'use [?] 
INSERT INTO Traces..ct_tables_controll
SELECT 
	db_name() database_name
	,sct2.name as schema_name
	,sot2.name as table_name
	,HASHBYTES(''SHA2_256'', db_name()+sct2.name+sot2.name) object_hash
FROM sys.internal_tables it
JOIN sys.objects sot1 on it.object_id=sot1.object_id
JOIN sys.schemas AS sct1 ON sot1.schema_id=sct1.schema_id
JOIN sys.dm_db_partition_stats ps1 ON it.object_id = ps1. object_id AND ps1.index_id in (0,1)
LEFT JOIN sys.objects sot2 on it.parent_object_id=sot2.object_id
JOIN sys.change_tracking_tables AS ctt ON ctt.object_id = sot2.object_id
LEFT JOIN sys.schemas AS sct2 ON sot2.schema_id=sct2.schema_id
WHERE it.internal_type IN (209, 210)
AND HASHBYTES(''SHA2_256'', db_name()+sct2.name+sot2.name)  NOT IN ((SELECT object_hash FROM Traces..ct_tables_controll))
'



SELECT * FROM Traces..ct_databases_controll
SELECT * FROM Traces..ct_tables_controll


