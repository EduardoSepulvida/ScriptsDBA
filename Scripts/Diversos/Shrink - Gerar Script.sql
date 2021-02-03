
/* PARAMETROS:
@base ->	NULL - para gerar todas bases 
			'Database' - informe o nome da base para gerar script somente dela

@system_databases ->	0 - para não gerar script das bases de sistema
						1 - para gerar script das bases de sistema
*/


DECLARE @base varchar(max) = NULL -- 'Traces'  
		,@system_databases bit = 0 
		

SET NOCOUNT ON;


IF OBJECT_ID('tempdb..#TEMP') IS NOT NULL
	DROP TABLE #TEMP

IF OBJECT_ID('tempdb..#ESPACO_DATABASES') IS NOT NULL
	DROP TABLE #ESPACO_DATABASES

CREATE TABLE #ESPACO_DATABASES (
	DRIVE CHAR(1)
	,BASE SYSNAME
	,GROUP_ID BIT
	,TAMANHO_ARQUIVO DECIMAL(15, 2)
	,ESPACO_UTILIZADO DECIMAL(15, 2)
	,ESPACO_LIVRE DECIMAL(15, 2)
	,ARQUIVO VARCHAR(100)
	,CAMINHO_ARQUIVO VARCHAR(255)
	)
	

INSERT INTO #ESPACO_DATABASES
	EXEC master.sys.sp_MSforeachdb ' USE [?];
	   SELECT  SUBSTRING(A.FILENAME, 1, 1) AS DRIVE
		  ,''[?]'' AS BASE
		  ,GROUPID AS GROUP_ID
		  ,CONVERT(DECIMAL(12, 2), ROUND(A.SIZE / 128.000, 2)) AS TAMANHO_ARQUIVO
		  ,CONVERT(DECIMAL(12, 2), ROUND(FILEPROPERTY(A.NAME, ''SPACEUSED'') / 128.000, 2)) AS ESPACO_UTILIZADO
		  ,CONVERT(DECIMAL(12, 2), ROUND((A.SIZE - FILEPROPERTY(A.NAME, ''SPACEUSED'')) / 128.000, 2)) AS ESPACO_LIVRE
		  ,A.NAME AS ARQUIVO
		  ,A.FILENAME AS CAMINHO_ARQUIVO
		FROM dbo.sysfiles A
		ORDER BY BASE, GROUPID DESC, ARQUIVO
			,DRIVE
	   '

IF @system_databases = 0 DELETE FROM #ESPACO_DATABASES WHERE  (BASE) IN ('[master]','[model]','[msdb]','[tempdb]')
IF @base IS NOT NULL DELETE FROM #ESPACO_DATABASES WHERE  (BASE) <> QUOTENAME(@base)
ALTER TABLE #ESPACO_DATABASES ADD ID INT IDENTITY

SELECT *,ROW_NUMBER() OVER (PARTITION BY BASE, GROUP_ID ORDER BY BASE, GROUP_ID DESC, ARQUIVO) RNK INTO #TEMP FROM #ESPACO_DATABASES t 

SELECT * FROM #TEMP ORDER BY BASE, GROUP_ID DESC, ARQUIVO

DECLARE @arquivo varchar(max)
		,@espaco_min varchar(max)
		,@espaco_usado varchar(max)
		,@id int


WHILE (SELECT COUNT(1) FROM #TEMP) > 0
	BEGIN
		SELECT TOP 1 @base = BASE, @id = ID, @arquivo = ARQUIVO, @espaco_min = (ESPACO_UTILIZADO), @espaco_usado=FLOOR(TAMANHO_ARQUIVO) FROM #TEMP ORDER BY BASE, GROUP_ID DESC, ARQUIVO
		PRINT 'USE ' + @base +'
GO'
		PRINT '--ESPAÇO MIN: ' + @espaco_min
		PRINT 'DBCC SHRINKFILE (N'''+@arquivo+''', '+@espaco_usado+')
GO'
		PRINT ''
		DELETE FROM #TEMP WHERE ID = @id
END
