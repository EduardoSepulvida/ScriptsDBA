
SET NOCOUNT ON;


IF OBJECT_ID('tempdb..#temp') is not null
	DROP TABLE #temp

CREATE TABLE #temp (
	id int identity,
	database_name varchar(max),
	file_id tinyint,
	name varchar(max),
	type bit
)

DECLARE @command varchar(1000) 
PRINT('--READ_ONLY')
SELECT @command = ' USE [?]
IF (DB_NAME() NOT IN(''master'',''tempdb'',''model'',''msdb''))
PRINT ''ALTER DATABASE [?] SET  OFFLINE WITH ROLLBACK IMMEDIATE'''
EXEC sp_MSforeachdb @command 





