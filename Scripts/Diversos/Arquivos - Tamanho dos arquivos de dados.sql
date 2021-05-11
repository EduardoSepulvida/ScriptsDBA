IF OBJECT_ID('tempdb..#ESPACO_DATABASES') IS NOT NULL
	DROP TABLE #ESPACO_DATABASES
CREATE TABLE #ESPACO_DATABASES (
	 DRIVE CHAR(1)
	,BASE SYSNAME
	,TAMANHO_ARQUIVO DECIMAL(15, 2)
	,ESPACO_UTILIZADO DECIMAL(15, 2)
	,ESPACO_LIVRE DECIMAL(15, 2)
	,PORCENTAGEM_LIVRE DECIMAL(15, 2)
	,ARQUIVO VARCHAR(100)
	,CAMINHO_ARQUIVO VARCHAR(255)
	)
INSERT INTO #ESPACO_DATABASES
EXEC master.sys.sp_MSforeachdb ' USE [?];
   SELECT  SUBSTRING(A.FILENAME, 1, 1) AS DRIVE
	  ,''?'' AS BASE
	  ,CONVERT(DECIMAL(12, 2), ROUND(A.SIZE / 128.000, 2)) AS TAMANHO_ARQUIVO
	  ,CONVERT(DECIMAL(12, 2), ROUND(FILEPROPERTY(A.NAME, ''SPACEUSED'') / 128.000, 2)) AS ESPACO_UTILIZADO
	  ,CONVERT(DECIMAL(12, 2), ROUND((A.SIZE - FILEPROPERTY(A.NAME, ''SPACEUSED'')) / 128.000, 2)) AS ESPACO_LIVRE
	  ,(CONVERT(DECIMAL(12, 2), ROUND((A.SIZE - FILEPROPERTY(A.NAME, ''SPACEUSED'')) / 128.000, 2)) / CONVERT(DECIMAL(12, 2), ROUND(A.SIZE / 128.000, 2)))*100 AS PORCENTAGEM_LIVRE
	  ,A.NAME AS ARQUIVO
	  ,A.FILENAME AS CAMINHO_ARQUIVO
	FROM dbo.sysfiles A
	ORDER BY ARQUIVO
		,DRIVE
   '

SELECT * FROM #ESPACO_DATABASES 

--------------------
SELECT
DatabaseName = DB_NAME()
,FilegroupName = FG.name
,F.file_id
,F.physical_name
,F.name
,F.file_id
,SizeGB = F.size/131072
,UsedGB = FILEPROPERTY(F.name,'SpaceUsed')/131072
,L.*
FROM
sys.database_files F
OUTER APPLY (
SELECT
LobGB = ISNULL(SUM(CASE WHEN AU.type_desc = 'LOB_DATA' THEN AU.total_pages ELSE 0 END)/131072,0)
,RowOverflowGB = ISNULL(SUM(CASE WHEN AU.type_desc = 'ROW_OVERFLOW_DATA' THEN AU.total_pages ELSE 0 END)/131072,0)
FROM
sys.allocation_units AU
WHERE
AU.data_space_id = F.data_space_id
) L
JOIN
sys.filegroups FG
ON FG.data_space_id = F.data_space_id

--------------------
SELECT CONVERT(VARCHAR(25), DB.name) AS [Database],
	 (SELECT COUNT(1) FROM sys.master_files WHERE DB_NAME(database_id) = DB.name AND type_desc = 'rows') AS [Data Files],
	 (SELECT SUM((size*8)/1024) FROM sys.master_files WHERE DB_NAME(database_id) = DB.name AND type_desc = 'rows') AS [Data MB],
	 (SELECT COUNT(1) FROM sys.master_files WHERE DB_NAME(database_id) = DB.name AND type_desc = 'log') AS [Log Files],
	 (SELECT SUM((size*8)/1024) FROM sys.master_files WHERE DB_NAME(database_id) = DB.name AND type_desc = 'log') AS [Log MB],
	 (SELECT SUM((size*8)/1024) FROM sys.master_files WHERE DB_NAME(database_id) = DB.name AND type_desc = 'log')*100/
	 (SELECT SUM((size*8)/1024) FROM sys.master_files WHERE DB_NAME(database_id) = DB.name AND type_desc = 'rows') [Diff Data Log (%)]
	-- INTO #Database_Files
  FROM sys.databases DB	 
	ORDER BY [Diff Data Log (%)] DESC


---------------------
-- BASE ATUAL INFO DETALHADA:
SELECT
    DatabaseName = DB_NAME()
	,FilegroupName = FG.name
	,F.file_id
    ,F.physical_name
    ,F.name
    ,F.file_id
    ,SizeGB = F.size/131072
    ,UsedGB = FILEPROPERTY(F.name,'SpaceUsed')/131072
    ,L.*
FROM
    sys.database_files F
    OUTER APPLY (
        SELECT
            LobGB = ISNULL(SUM(CASE WHEN AU.type_desc = 'LOB_DATA' THEN AU.total_pages ELSE 0 END)/131072,0)
			,RowOverflowGB = ISNULL(SUM(CASE WHEN AU.type_desc = 'ROW_OVERFLOW_DATA' THEN AU.total_pages ELSE 0 END)/131072,0)
        FROM
            sys.allocation_units AU
        WHERE
            AU.data_space_id = F.data_space_id
    ) L
	JOIN
	sys.filegroups FG
		ON FG.data_space_id = F.data_space_id


----------------------


SELECT name, size = size/128.0,max_size,type_desc FROM sys.database_files 

----------------------

 IF (OBJECT_ID('tempdb..#Alert_MDFs_Sizes') IS NOT NULL)  
  DROP TABLE #Alert_MDFs_Sizes  
     
 CREATE TABLE #Alert_MDFs_Sizes (  
  [Server]   VARCHAR(500),  
  [Nm_Database]  VARCHAR(500),  
  [Logical_Name]  VARCHAR(500),  
  [Type]  VARCHAR(500),  
  [Max_Size]   NUMERIC(15,2),  
  [Size]    NUMERIC(15,2),  
  [Total_Used] NUMERIC(15,2),  
  [Free_Space (MB)] NUMERIC(15,2),  
  [Percent_Free] NUMERIC(15,2)  
 )  
  
 EXEC sp_MSforeachdb '  
  Use [?]  
  
   ;WITH cte_datafiles AS   
   (  
     SELECT name, size = size/128.0,max_size,type_desc FROM sys.database_files  
   ),  
   cte_datainfo AS  
   (  
     SELECT name,type_desc, max_size,CAST(size as numeric(15,2)) as size,   
      CAST( (CONVERT(INT,FILEPROPERTY(name,''SpaceUsed''))/128.0) as numeric(15,2)) as used,   
      free = CAST( (size - (CONVERT(INT,FILEPROPERTY(name,''SpaceUsed''))/128.0)) as numeric(15,2))  
     FROM cte_datafiles  
   )  
  
   INSERT INTO #Alert_MDFs_Sizes  
   SELECT @@SERVERNAME, DB_NAME(), name as [Logical_Name],type_desc, (max_size * 8)/1024.00 max_size,size, used, free,  
     percent_free = case when size <> 0 then cast((free * 100.0 / size) as numeric(15,2)) else 0 end  
   FROM cte_datainfo   
   where max_size <> -1 AND max_size < 268435456  
 '   
  
 select Nm_Database, Logical_Name, [Type], Size,Total_Used,[Free_Space (MB)],Percent_Free, Max_Size  
 from #Alert_MDFs_Sizes  


/*
--Liberar tempdb

DBCC FREEPROCCACHE
GO
DBCC DROPCLEANBUFFERS
go
DBCC FREESYSTEMCACHE ('ALL')
GO
DBCC FREESESSIONCACHE
GO
*/
