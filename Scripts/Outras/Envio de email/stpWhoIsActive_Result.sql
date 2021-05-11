
CREATE PROCEDURE [dbo].[stpWhoIsActive_Result]
AS
BEGIN
		IF ( OBJECT_ID('tempdb..#WhoIsActive_Result') IS NOT NULL )
		DROP TABLE #WhoIsActive_Result
	
	-- Table with the WhoisActive Result that will be used for all Alert Procedures 
	CREATE TABLE #WhoIsActive_Result(		
		[dd hh:mm:ss.mss]		VARCHAR(20),
		[database_name]			VARCHAR(128),		
		[login_name]			VARCHAR(128),
		[host_name]				VARCHAR(128),
		[start_time]			datetime,
		[status]				VARCHAR(30),
		[session_id]			INT,
		[blocking_session_id]	INT,
		[wait_info]				VARCHAR(MAX),
		[open_tran_count]		INT,
		[CPU]					VARCHAR(MAX),
		[CPU_delta]				VARCHAR(MAX),
		[reads]					VARCHAR(MAX),
		[reads_delta]			VARCHAR(MAX),
		[writes]				VARCHAR(MAX),		
		[sql_command]			XML,
		[sql_text]			XML				
	)   
			
	EXEC [dbo].[sp_whoisactive]
			@get_outer_command =	1,
			@delta_interval = 1,
			@output_column_list =	'[dd hh:mm:ss.mss][database_name][login_name][host_name][start_time][status][session_id][blocking_session_id][wait_info][open_tran_count][CPU][CPU_delta][reads][reads_delta][writes][sql_command][sql_text]',
			@destination_table =	'#WhoIsActive_Result'
						
		ALTER TABLE #WhoIsActive_Result
		ALTER COLUMN [sql_command] NVARCHAR(MAX)

		UPDATE #WhoIsActive_Result
		SET [sql_command] = REPLACE( REPLACE( REPLACE( REPLACE( CAST([sql_command] AS NVARCHAR(4000)), '<?query --', ''), '--?>', ''), '&gt;', '>'), '&lt;', '')

		ALTER TABLE #WhoIsActive_Result
		ALTER COLUMN [sql_text] NVARCHAR(MAX)

		UPDATE #WhoIsActive_Result
		SET [sql_text] = REPLACE( REPLACE( REPLACE( REPLACE( CAST([sql_text] AS NVARCHAR(4000)), '<?query --', ''), '--?>', ''), '&gt;', '>'), '&lt;', '')

		IF ( OBJECT_ID('tempdb..##WhoIsActive_Result') IS NOT NULL )
			DROP TABLE ##WhoIsActive_Result
	/*
		CREATE TABLE ##WhoIsActive_Result(		
		[dd hh:mm:ss.mss]		VARCHAR(20),
		[Database]			VARCHAR(128),		
		[Login]			VARCHAR(128),
		[Host Name]				VARCHAR(128),
		[Start Time]			varchar(20),
		[Status]				VARCHAR(30),
		[Session ID]			INT,
		[Blocking Session ID]	INT,
		[Wait Info]				VARCHAR(MAX),
		[Open Tran Count]		INT,
		[CPU]					VARCHAR(MAX),
		[CPU Delta]				VARCHAR(MAX),
		[Reads]					VARCHAR(MAX),
		[Reads Delta]			VARCHAR(MAX),
		[Writes]				VARCHAR(MAX),		
		[Query]				VARCHAR(MAX)
				
	)   
		
	insert into ##WhoIsActive_Result		
	select [dd hh:mm:ss.mss], [database_name], [login_name], [host_name], ISNULL(CONVERT(VARCHAR(20), [start_time], 120), '-') start_time, [status], [session_id], [blocking_session_id], 
	[wait_info], [open_tran_count], [CPU], [CPU_delta], [reads], [reads_delta], [writes], isnull([sql_command],[sql_text]) Query
	from 	#WhoIsActive_Result
	*/


		CREATE TABLE ##WhoIsActive_Result(		
		[dd hh:mm:ss.mss]		CHAR(20),
		[Database]			VARCHAR(128),		
		[Login]			VARCHAR(128),
		[Host Name]				VARCHAR(128),
		[Start Time]			varchar(20),
		[Status]				VARCHAR(30),
		[Session ID]			INT,
		[Blocking Session ID]	INT,
		[Wait Info]				VARCHAR(200),
		[Open Tran Count]		INT,
		[CPU]					VARCHAR(200),
		[CPU Delta]				VARCHAR(200),
		[Reads]					VARCHAR(200),
		[Reads Delta]			VARCHAR(200),
		[Writes]				VARCHAR(200),		
		[Query]			Varchar(300)
				
	)   
		
	insert into ##WhoIsActive_Result		
	select [dd hh:mm:ss.mss], [database_name], [login_name], [host_name], ISNULL(CONVERT(VARCHAR(20), [start_time], 120), '-') start_time, [status], [session_id], [blocking_session_id], 
	substring([wait_info],1,50), [open_tran_count], [CPU], [CPU_delta], [reads], [reads_delta], [writes], substring(isnull([sql_command],[sql_text]),1,100) Query
	from 	#WhoIsActive_Result
				
				
	IF NOT EXISTS ( SELECT TOP 1 * FROM ##WhoIsActive_Result )
	BEGIN
		INSERT INTO ##WhoIsActive_Result
		SELECT NULL, NULL, NULL, NULL, NULL, '-', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL 
	END

		
END
