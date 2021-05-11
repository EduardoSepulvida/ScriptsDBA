
CREATE OR ALTER PROCEDURE stpPackagesHistory(
		@dateStart date = NULL
		,@dateFinish date = NULL)
AS
BEGIN

	SELECT	folder_name
			,project_name
			,package_name
			,CAST(start_time AS DATETIME)start_time
			,CAST(end_time AS DATETIME)end_time
			,HASHBYTES('SHA2_256',folder_name+project_name+package_name) package_hash
			,HASHBYTES('SHA2_256',folder_name+project_name) project_hash
	INTO #temp_package_time
	FROM SSISDB.internal.execution_info
	WHERE(					
				(cast(start_time  as date) = @dateStart AND @dateFinish IS NULL)
			OR	(cast(start_time  as date) = cast(GETDATE() as date) AND @dateStart IS NULL AND @dateFinish IS NULL)
			OR	(cast(start_time  as date) >= @dateStart AND (cast(start_time  as date) <= @dateFinish))
	)
	--AND package_name = 'CHAMADOR_TRANSIS_FAT.dtsx'
	ORDER BY start_time


	SELECT replace(name,'.dtsx','') name
	INTO #temp_packages_names 
	FROM SSISDB.catalog.packages


	select 
		SQLInstance
		,job
		,Enabled
		,step
		,SSIS_Package path
		,len(SSIS_Package) pathlen
		,StorageType
		,Server
	into #temp
	from (
		select SQLInstance = @@ServerName
		, [job]=j.name
		, j.Enabled
		, [step]=s.step_name
		, SSIS_Package= case 
					 when charindex('/ISSERVER', s.command)=1 then substring(s.command, len('/ISSERVER "\"')+1, charindex('" /SERVER ', s.command)-len('/ISSERVER "\"')-3)
					 when charindex('/FILE', s.command)=1 then substring(s.command, len('/FILE "')+1, charindex('.dtsx', s.command)-len('/FILE "\"')+6)
					 when charindex('/SQL', s.command)=1 then substring(s.command, len('/SQL "\"')+1, charindex('" /SERVER ', s.command)-len('/SQL "\"')-3)
					 else s.command
					end
		, StorageType = CASE 
					 when charindex('/ISSERVER', s.command) = 1 then 'SSIS Catalog'
					 when charindex('/FILE', s.command)=1 then 'File System'
					 when charindex('/SQL', s.command)=1 then 'MSDB'
					 else 'OTHER'
					end
		, [Server] = CASE 
					 when charindex('/ISSERVER', s.command) = 1 then replace(replace(substring(s.command, charindex('/SERVER ', s.command)+len('/SERVER ')+1, charindex(' /', s.command, charindex('/SERVER ', s.command)+len('/SERVER '))-charindex('/SERVER ', s.command)-len('/SERVER ')-1), '"\"',''), '\""', '')
					 when charindex('/FILE', s.command)=1 then substring(s.command, charindex('"\\', s.command)+3, CHARINDEX('\', s.command, charindex('"\\', s.command)+3)-charindex('"\\', s.command)-3)
					 when charindex('/SQL', s.command)=1 then replace(replace(substring(s.command, charindex('/SERVER ', s.command)+len('/SERVER ')+1, charindex(' /', s.command, charindex('/SERVER ', s.command)+len('/SERVER '))-charindex('/SERVER ', s.command)-len('/SERVER ')-1), '"\"',''), '\""', '')
					 else 'OTHER'
					END
		from msdb.dbo.sysjobsteps s
		inner join msdb.dbo.sysjobs j
		on s.job_id = j.job_id
		and s.subsystem ='SSIS'
		and charindex('/ISSERVER', s.command) = 1 --StorageType = 'SSIS Catalog'
	)x
	where x.Server = 'HOLDEN'
	and x.enabled = 1


	select distinct 
			t.job
			--,t.step
			,t.path
			,f5.folder
			,f3.project
			,f1.package   
			,package_info.task_Component
			,package_info.task_Start
			,package_info.task_Finish
			,package_info.task_Duration
			,package_info.task_Status
			,HASHBYTES('SHA2_256',f5.folder+f3.project+f1.package) package_hash
			,HASHBYTES('SHA2_256',f5.folder+f3.project) project_hash
	into #temp2
	from #temp t
	CROSS APPLY ( SELECT RIGHT(t.path,CHARINDEX('\',REVERSE(t.path))-1)package ) f1
	CROSS APPLY ( SELECT SUBSTRING(t.path,t.pathlen-CHARINDEX('\',REVERSE(t.path),len(f1.package)+2)+2,t.pathlen-len(f1.package)) project) f2
	CROSS APPLY ( SELECT SUBSTRING(f2.project,1,CHARINDEX('\',f2.project)-1) project) f3
	CROSS APPLY ( SELECT CHARINDEX('\',SUBSTRING(t.path,2,t.pathlen)) folder) f4
	CROSS APPLY ( SELECT SUBSTRING(t.path,f4.folder+2,CHARINDEX('\',SUBSTRING(t.path,f4.folder+2,t.pathlen))-1) folder) f5
	CROSS APPLY ( SELECT 
						e.execution_id
						,e.package_name
						,e.executable_name task_Component
						,e.package_path
						, CONVERT(datetime, es.start_time) AS task_Start
						, CONVERT(datetime, es.end_time) AS task_Finish
						, CAST(es.execution_duration/1000.0 AS DECIMAL(16,3)) task_Duration 
						, case es.execution_result when 0 then 'Success' when 1 then 'Failure' when 2 then 'Completion' when 3 then 'Cancelled' end  as task_Status
					from ssisdb.catalog.executables e
					join ssisdb.catalog.executable_statistics es
					on  e.executable_id = es.executable_id
						and e.execution_id = es.execution_id
					where (
							(cast(start_time  as date) = @dateStart AND @dateFinish IS NULL)
						OR	(cast(start_time  as date) = cast(GETDATE() as date) AND @dateStart IS NULL AND @dateFinish IS NULL)
						OR	(cast(start_time  as date) >= @dateStart AND (cast(start_time  as date) <= @dateFinish))
						)
					and package_name = f1.package  COLLATE SQL_Latin1_General_CP1_CI_AI				
	)package_info
	LEFT JOIN 
		#temp_packages_names 
		ON #temp_packages_names.name = package_info.task_Component
	WHERE #temp_packages_names.name IS NOT NULL
	ORDER BY task_Start, task_Finish
	OPTION(RECOMPILE)


SELECT	DISTINCT
			folder
			,project
			,MIN(package_Start) OVER(PARTITION BY project_hash) project_Start
			,MAX(package_Finish) OVER(PARTITION BY project_hash) project_Finish
			,package
			,package_Start
			,package_Finish
			,task_Component
			,task_Start
			,task_Finish
			,task_Status

FROM (
	SELECT	
			
			folder
			,project
			,project_hash
			,package   
			,(SELECT MAX(t.start_time) FROM #temp_package_time t WHERE t.package_hash = t2.package_hash AND t.start_time <= t2.task_Finish) package_Start
			,(SELECT MAX(t.end_time) FROM #temp_package_time t WHERE t.package_hash = t2.package_hash AND t.start_time <= t2.task_Finish) package_Finish
			,task_Component
			,task_Start
			,task_Finish
			,task_Duration
			,task_Status
	FROM 
		#temp2 t2
)x
	ORDER BY task_Start 


	DROP TABLE #temp,#temp2,#temp_package_time,#temp_packages_names

END



/*
CHAMADOR ASTREIN.dtsx
CHAMADOR_CITEL_DIM.dtsx
CHAMADOR_CITEL_FAT.dtsx
CHAMADOR_MOTOR.dtsx
CHAMADOR_PROTHEUS_DIM.dtsx
CHAMADOR_PROTHEUS_FAT.dtsx
CHAMADOR_TRANSIS_DIM.dtsx
CHAMADOR_TRANSIS_FAT.dtsx
*/
--2021-05-06 01:21:57.1580004 -03:00

/*
select * from ssisdb.[catalog].[event_messages] where message_time >= '20210506' and event_name IN('OnError') order by message_time
--OnError
--OnTaskFailed
--71767

select * from ssisdb.[catalog].executable_statistics where start_time >= '20210506' order by start_time

select top 10 * from ssisdb.[catalog].executables


select distinct event_name from ssisdb.[catalog].[event_messages] where message_time >= '20210506' order by message_time


SELECT folder_name, project_name, package_name,
CAST(start_time AS DATETIME)start_time,
CAST(end_time AS DATETIME)end_time
FROM SSISDB.internal.execution_info
WHERE start_time >= '20210506'
--AND package_name = 'CHAMADOR_TRANSIS_FAT.dtsx'
ORDER BY start_time
	
*/
