USE [Traces]
GO
/****** Object:  StoredProcedure [dbo].[stpLock_Raiz]    Script Date: 27/04/2021 19:51:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[stpLock_Raiz] @Dt_Lock datetime = NULL
AS
BEGIN
	-- Cria a tabela que ira armazenar os dados dos processos
	IF ( OBJECT_ID('tempdb..#Resultado_WhoisActive') IS NOT NULL )
		DROP TABLE #Resultado_WhoisActive
  
	CREATE TABLE #Resultado_WhoisActive (  
		[dd hh:mm:ss.mss]  VARCHAR(20),
		[database_name]   NVARCHAR(128),  
		[login_name]   NVARCHAR(128),
		[host_name]    NVARCHAR(128),
		[start_time]   DATETIME,
		[status]    VARCHAR(30),
		[session_id]   INT,
		[blocking_session_id] INT,
		[wait_info]    VARCHAR(MAX),
		[open_tran_count]  INT,
		[CPU]     VARCHAR(MAX),
		[reads]     VARCHAR(MAX),
		[writes]    VARCHAR(MAX),  
		[sql_command]   XML  
	)   
	
	-- Se não informar data, verifica o status atual
	IF(@Dt_Lock IS NULL)
	BEGIN 
		--------------------------------------------------------------------------------------------------------------------------------
		-- Carrega os Dados da SP_WHOISACTIVE
		--------------------------------------------------------------------------------------------------------------------------------
		-- Retorna todos os processos que estão sendo executados no momento
		EXEC [dbo].[sp_WhoIsActive]
			@get_outer_command = 1,
			@output_column_list = '[dd hh:mm:ss.mss][database_name][login_name][host_name][start_time][status][session_id][blocking_session_id][wait_info][open_tran_count][CPU][reads][writes][sql_command]',
			@destination_table = '#Resultado_WhoisActive'
	END
	ELSE -- Caso informe a data, verifica as queries do momento exato informado
	BEGIN
		INSERT INTO #Resultado_WhoisActive
		SELECT	[dd hh:mm:ss.mss], [database_name], [login_name], [host_name], Dt_Log, [status], [session_id], 
				[blocking_session_id], [wait_info], [open_tran_count], [CPU], [reads], [writes], [sql_command]
		FROM dbo.Resultado_WhoIsActive (nolock)
		WHERE Dt_Log = @Dt_Lock
	END

	-- Altera a coluna que possui o comando SQL
	ALTER TABLE #Resultado_WhoisActive
	ALTER COLUMN [sql_command] VARCHAR(MAX)
 
	UPDATE #Resultado_WhoisActive
	SET [sql_command] = REPLACE( REPLACE( REPLACE( REPLACE( CAST([sql_command] AS VARCHAR(1000)), '<?query --', ''), '--?>', ''), '&gt;', '>'), '&lt;', '')  

	--------------------------------------------------------------------------------------------------------------------------------
	-- Verifica o Nivel dos Locks
	--------------------------------------------------------------------------------------------------------------------------------
	ALTER TABLE #Resultado_WhoisActive
	ADD Nr_Nivel_Lock TINYINT 

	-- Nivel 0
	UPDATE A
	SET Nr_Nivel_Lock = 0
	FROM #Resultado_WhoisActive A
	WHERE blocking_session_id IS NULL AND session_id IN ( SELECT DISTINCT blocking_session_id 
				FROM #Resultado_WhoisActive WHERE blocking_session_id IS NOT NULL)

	UPDATE A
	SET Nr_Nivel_Lock = 1
	FROM #Resultado_WhoisActive A
	WHERE	Nr_Nivel_Lock IS NULL
			AND blocking_session_id IN ( SELECT DISTINCT session_id FROM #Resultado_WhoisActive WHERE Nr_Nivel_Lock = 0)

	UPDATE A
	SET Nr_Nivel_Lock = 2
	FROM #Resultado_WhoisActive A
	WHERE	Nr_Nivel_Lock IS NULL
			AND blocking_session_id IN ( SELECT DISTINCT session_id FROM #Resultado_WhoisActive WHERE Nr_Nivel_Lock = 1)

	UPDATE A
	SET Nr_Nivel_Lock = 3
	FROM #Resultado_WhoisActive A
	WHERE	Nr_Nivel_Lock IS NULL
			AND blocking_session_id IN ( SELECT DISTINCT session_id FROM #Resultado_WhoisActive WHERE Nr_Nivel_Lock = 2)

	-- Tratamento quando não tem um Lock Raiz
	IF NOT EXISTS(select * from #Resultado_WhoisActive where Nr_Nivel_Lock IS NOT NULL)
	BEGIN
		UPDATE A
		SET Nr_Nivel_Lock = 0
		FROM #Resultado_WhoisActive A
		WHERE session_id IN ( SELECT DISTINCT blocking_session_id 
			FROM #Resultado_WhoisActive WHERE blocking_session_id IS NOT NULL)
          
		UPDATE A
		SET Nr_Nivel_Lock = 1
		FROM #Resultado_WhoisActive A
		WHERE	Nr_Nivel_Lock IS NULL
				AND blocking_session_id IN ( SELECT DISTINCT session_id FROM #Resultado_WhoisActive WHERE Nr_Nivel_Lock = 0)

		UPDATE A
		SET Nr_Nivel_Lock = 2
		FROM #Resultado_WhoisActive A
		WHERE	Nr_Nivel_Lock IS NULL
				AND blocking_session_id IN ( SELECT DISTINCT session_id FROM #Resultado_WhoisActive WHERE Nr_Nivel_Lock = 1)

		UPDATE A
		SET Nr_Nivel_Lock = 3
		FROM #Resultado_WhoisActive A
		WHERE	Nr_Nivel_Lock IS NULL
				AND blocking_session_id IN ( SELECT DISTINCT session_id FROM #Resultado_WhoisActive WHERE Nr_Nivel_Lock = 2)
	END

	-- Retorna o resultado -- incluir nivel
	SELECT
		CAST(Nr_Nivel_Lock AS VARCHAR)       AS [Nr_Nivel_Lock],
		ISNULL([dd hh:mm:ss.mss], '-')       AS [Duração], 
		ISNULL([database_name], '-')       AS [database_name],
		ISNULL([login_name], '-')        AS [login_name],
		ISNULL([host_name], '-')        AS [host_name],
		ISNULL(CONVERT(VARCHAR(20), [start_time], 120), '-') AS [start_time],
		ISNULL([status], '-')         AS [status],
		ISNULL(CAST([session_id] AS VARCHAR), '-')    AS [session_id],
		ISNULL(CAST([blocking_session_id] AS VARCHAR), '-')  AS [blocking_session_id],
		ISNULL([wait_info], '-')        AS [Wait],
		ISNULL(CAST([open_tran_count] AS VARCHAR), '-')   AS [open_tran_count],
		ISNULL([CPU], '-')          AS [CPU],
		ISNULL([reads], '-')         AS [reads],
		ISNULL([writes], '-')         AS [writes],
		[sql_command]
	FROM #Resultado_WhoisActive
	WHERE Nr_Nivel_Lock IS NOT NULL
	ORDER BY [Nr_Nivel_Lock], [start_time] 
END

