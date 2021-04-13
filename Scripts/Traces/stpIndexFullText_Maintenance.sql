USE Traces
GO

CREATE or ALTER PROCEDURE stpIndexFullText_Maintenance
AS
BEGIN

	SET LOCK_TIMEOUT 300000  -- Se ficar bloqueado por mais de 5 minutos, aborta.

	IF object_id('tempdb..#fulltextFragmentationDetails') IS NOT NULL 
		DROP TABLE #fulltextFragmentationDetails

	CREATE TABLE #fulltextFragmentationDetails(
		id int identity(1,1),
		database_name sysname,
		fulltext_catalog_id int,
		fulltext_catalog_name sysname,
		object_id int,
		object_name nvarchar(248),
		num_fragments int,
		fulltext_mb decimal(9,2),
		largest_fragment_mb decimal(9,2),
		fulltext_fragmentation_in_percent DECIMAL(9,2)
	)

	DECLARE @command varchar(1000),
			@id int,
			@sql nvarchar(1000)

	-- OBTEM OS ÍNDICES FULLTEXT DE TODOS OS BANCOS
	SELECT @command = 'USE ? 
	INSERT INTO #fulltextFragmentationDetails
	SELECT 
		DB_NAME()database_name, c.fulltext_catalog_id, c.name AS fulltext_catalog_name,
		i.object_id, OBJECT_SCHEMA_NAME(i.object_id) + ''.'' + OBJECT_NAME(i.object_id) AS object_name,
		f.num_fragments, f.fulltext_mb, f.largest_fragment_mb,
		100.0 * (f.fulltext_mb - f.largest_fragment_mb) / NULLIF(f.fulltext_mb, 0) AS fulltext_fragmentation_in_percent
	FROM 
		sys.fulltext_catalogs c
	JOIN 
		sys.fulltext_indexes i
		ON i.fulltext_catalog_id = c.fulltext_catalog_id
	JOIN (
		SELECT 
			table_id,
			COUNT(*) AS num_fragments,
			CONVERT(DECIMAL(9,2), SUM(data_size/(1024.*1024.))) AS fulltext_mb,
			CONVERT(DECIMAL(9,2), MAX(data_size/(1024.*1024.))) AS largest_fragment_mb
		FROM 
			sys.fulltext_index_fragments
		GROUP BY 
			table_id
	) f
		ON f.table_id = i.object_id' 


	EXEC sp_MSforeachdb @command 


	-- DE ACORDO COM A FRAGMENTAÇÃO PREPARA O SCRIPT PARA REBUILD OU REORGANIZE
	SELECT 
			id,'USE ' + database_name + ' ALTER FULLTEXT CATALOG '+fulltext_catalog_name+ CASE WHEN fulltext_fragmentation_in_percent >= 30 THEN ' REBUILD' ELSE ' REORGANIZE' END sql
		INTO 
			#fulltextFragmentationDetailsFinal
		FROM 
			#fulltextFragmentationDetails
	 
	-- ENQUANTO TIVER ÍNDICES FULLTEXT A SER PROCESSADO, IRÁ REALIZAR O REBUILD OU REORGANIZE
	WHILE exists (SELECT Id FROM #fulltextFragmentationDetailsFinal)
	BEGIN 
		SELECT @id = id, @sql = sql FROM #fulltextFragmentationDetailsFinal ORDER BY id

		-- EXECUTA REBUILD OU REORGANIZE
		exec sp_executesql @sql
	
		DELETE #fulltextFragmentationDetailsFinal WHERE id = @id
	END

END