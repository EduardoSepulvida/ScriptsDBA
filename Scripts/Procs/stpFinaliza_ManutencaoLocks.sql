USE [Traces]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[stpFinaliza_ManutencaoLocks]
AS
BEGIN
	SET NOCOUNT ON



if OBJECT_ID('tempdb..#Resultado_WhoisActive') is not null
	drop table #Resultado_WhoisActive
	
	--------------------------------------------------------------------------------------------------------------------------------
	--	Cria Tabela para armazenar os Dados da SP_WHOISACTIVE
	--------------------------------------------------------------------------------------------------------------------------------
	-- Cria a tabela que ira armazenar os dados dos processos
	IF ( OBJECT_ID('tempdb..#Resultado_WhoisActive') IS NOT NULL )
		DROP TABLE #Resultado_WhoisActive
		
	CREATE TABLE #Resultado_WhoisActive (		
		[session_id]			INT,
		[blocking_session_id]	INT,
		[program_name]			NVARCHAR(1000)		
	)       
      
	--------------------------------------------------------------------------------------------------------------------------------
	--	Carrega os Dados da SP_WHOISACTIVE
	--------------------------------------------------------------------------------------------------------------------------------
	-- Retorna todos os processos que estão sendo executados no momento
	EXEC [dbo].[sp_WhoIsActive]
			@get_outer_command =	1,
			@output_column_list =	'[session_id][blocking_session_id][program_name]',
			@destination_table =	'#Resultado_WhoisActive'
				    
	
    --select * from #Resultado_WhoisActive
    
    
	if OBJECT_ID('tempdb..#Processos') is not null
		drop table #Processos
	
    select session_id
    into #Processos
    from #Resultado_WhoisActive A
		cross apply(			
				SELECT max(wait_time)wait_time FROM sys.dm_exec_requests r where r.blocking_session_id = A.session_id having max(wait_time) > 90000 --1min30 de lock
		)x
	where SUBSTRING([program_name],30,35) in(select CONVERT(binary(16), job_id) FROM msdb.dbo.sysjobs where name in('DBA - Index Maintenance','DBA - Update Statistics'))
		 

		

	--select * from #Processos
	
	Declare @SpId as varchar(5)

	while (select count(*) from #Processos) >0
	begin
		
		select top 1 @SpId = session_id from #Processos
		
		print('kill ' + @SpId)

	    exec ('Kill ' + 	@SpId)
	
		delete from #Processos where session_id = @SpId
	End
	
END

