USE [master]

GO
-- Verificar disco o qual armazenará os arquivos do server audit - E:\Audit
CREATE SERVER AUDIT [AuditLog]
TO FILE 
(	FILEPATH = N'D:\Traces\Audit'
	,MAXSIZE = 64 MB
	,MAX_ROLLOVER_FILES = 16
	,RESERVE_DISK_SPACE = OFF
)
WITH
(	QUEUE_DELAY = 1000
	,ON_FAILURE = CONTINUE
)
WHERE ([schema_name]<> 'sys' )

GO


USE [BDPecas]

GO

CREATE DATABASE AUDIT SPECIFICATION [AuditLogDelete]
FOR SERVER AUDIT [AuditLog]
ADD (DELETE ON OBJECT::[dbo].[CLI] BY [public]),
ADD (DELETE ON OBJECT::[dbo].[CLI_COMPL] BY [public])

GO


/*

--SELECT VALIDANDO AUDITS
-- Retorna as informações de um arquivo específico
SELECT * 
FROM msdb.sys.fn_get_audit_file('D:\Traces\Audit\*.sqlaudit',default,default)  

-- Retorna as informações de todos os arquivos
SELECT event_time,action_id,server_principal_name,statement,* 
FROM msdb.sys.fn_get_audit_file('D:\Traces\Audit\*.sqlaudit',default,default)

*/

--Criar base Traces

CREATE DATABASE Traces
ALTER DATABASE Traces SET RECOVERY SIMPLE


-- PROCEDURE PARA CARREGAMENTO DOS DADOS NA TABELA AUDITORIA


USE [Traces]
GO
/****** Object:  StoredProcedure [dbo].[stpCarrega_Dados_tabelaCLI]    Script Date: 02/02/2021 02:00:07 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[stpCarrega_Dados_tabelaCLI]
AS
BEGIN


	IF (OBJECT_ID('Traces..AuditLog_tabelaCLI') IS NULL)
	BEGIN

		CREATE TABLE Traces..AuditLog_tabelaCLI (
			Id_Auditoria BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY CLUSTERED,
			Dt_Auditoria DATETIME NOT NULL,
			Cd_Acao VARCHAR(60) NOT NULL,
			Ds_Maquina VARCHAR(128) NOT NULL,
			Ds_Usuario VARCHAR(128) NOT NULL,
			Ds_Database VARCHAR(128) NOT NULL,
			Ds_Schema VARCHAR(128) NOT NULL,
			Ds_Objeto VARCHAR(128) NOT NULL,
			Ds_Query VARCHAR(MAX) NOT NULL,
			Fl_Sucesso BIT NOT NULL
			--Ds_Arquivo_Trace VARCHAR(400) NOT NULL,
			/*Ds_IP VARCHAR(128) NOT NULL,
			Ds_Programa VARCHAR(128) NOT NULL,
			Qt_Duracao BIGINT NOT NULL,
			Qt_Linhas_Retornadas BIGINT NOT NULL,
			Qt_Linhas_Alteradas BIGINT NOT NULL*/
		) WITH(DATA_COMPRESSION=PAGE)

	END


	DECLARE @TimeZone INT = DATEDIFF(HOUR, GETUTCDATE(), GETDATE())
	DECLARE @Dt_Max DATETIME = DATEADD(SECOND, 1, ISNULL((SELECT MAX(Dt_Auditoria) FROM Traces..AuditLog_tabelaCLI), '1900-01-01'))


	INSERT INTO Traces..AuditLog_tabelaCLI
	(
		Dt_Auditoria,
		Cd_Acao,
		Ds_Maquina,
		Ds_Usuario,
		Ds_Database,
		Ds_Schema,
		Ds_Objeto,
		Ds_Query,
		Fl_Sucesso
		/*Ds_IP,
		Ds_Programa,
		Qt_Duracao,
		Qt_Linhas_Retornadas,
		Qt_Linhas_Alteradas*/
	)
	SELECT DISTINCT
		DATEADD(HOUR, @TimeZone, event_time) AS event_time,
		action_id,
		server_instance_name,
		server_principal_name,
		[database_name],
		[schema_name],
		[object_name],
		[statement],
		succeeded
		/*client_ip,
		application_name,
		duration_milliseconds,
		response_rows,
		affected_rows*/
	FROM 
		sys.fn_get_audit_file('D:\Traces\Audit\*.sqlaudit', DEFAULT, DEFAULT)
	WHERE 
		DATEADD(HOUR, @TimeZone, event_time) >= @Dt_Max


END
GO




-- CRIA JOB PARA CARREGAR DADOS A CADA 5 MINUTOS

USE [msdb]
GO

/****** Object:  Job [DBA - CarregaDadostabelas]    Script Date: 02/02/2021 02:03:28 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Data Collector]    Script Date: 02/02/2021 02:03:28 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Data Collector' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Data Collector'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA - CarregaDadostabelas', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'Data Collector', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Executa stp]    Script Date: 02/02/2021 02:03:29 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Executa stp', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=1, 
		@retry_interval=1, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'exec stpCarrega_Dados_tabelaCLI', 
		@database_name=N'Traces', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'5 min', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=5, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20201230, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'92490a50-fcca-48b3-b23a-9009ae1f393c'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO






