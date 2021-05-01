

CREATE OR ALTER PROCEDURE stpLimpa_Cache_Consulta_Causando_Lock
AS
/*
	OBJETIVO: Há uma query pegando planos ruins e causando locks no ambiente. Por ser chamada diretamente por uma app, sua manutenção não pode ser feita imediata, 
			sugerimos acrescentar o OPTION(RECOMIPILE) ao final da query. Até subirem a correção, esta procedure será executada em job tentando evitar planos ruins por muito tempo.
	
	AUTOR: POWER TUNING - EDUARDO RABELO
	DATA: 29/04/2021 16:50

*/
BEGIN
	IF OBJECT_ID('tempdb..#temp_plan_handle') IS NOT NULL
		DROP TABLE #temp_plan_handle

	SELECT 
		'DBCC FREEPROCCACHE (0x' + convert(varchar(max), plan_handle, 2) + ');' command
	INTO 
		#temp_plan_handle
	FROM sys.dm_exec_cached_plans   
	CROSS APPLY sys.dm_exec_sql_text(plan_handle) AS st  
	WHERE text LIKE N'(@AgreementName nvarchar(4000)%AND P%TicketName% IS NULL%';


	DECLARE @command nvarchar(max)

	WHILE (SELECT COUNT(1) FROM #temp_plan_handle) > 0
	BEGIN
		select @command = command FROM #temp_plan_handle order by command

		exec sp_executesql @command

		DELETE TOP(1) FROM #temp_plan_handle WHERE command = @command

	END

END