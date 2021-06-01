DECLARE @DATE DATE = GETDATE() - 7 -- This is to restrict the data for last 7 days, used in ON condition 

SELECT O.Operation_Id -- Not much of use 
,E.Folder_Name AS Project_Name 
,E.Project_name AS SSIS_Project_Name 
,EM.Package_Name 
,CONVERT(DATETIME, O.start_time) AS Start_Time 
,CONVERT(DATETIME, O.end_time) AS End_Time 
,OM.message as [Error_Message] 
,EM.Event_Name 
,EM.Message_Source_Name AS Component_Name 
,EM.Subcomponent_Name AS Sub_Component_Name 
,E.Environment_Name 
,CASE E.Use32BitRunTime 
WHEN 1 
THEN 'Yes' 
ELSE 'NO' 
END Use32BitRunTime 
,EM.Package_Path 
,E.Executed_as_name AS Executed_By 

FROM [SSISDB].[internal].[operations] AS O 
INNER JOIN [SSISDB].[internal].[event_messages] AS EM 
ON o.start_time >= @date -- Restrict data by date 
AND EM.operation_id = O.operation_id 

-- Edit: I change the alias from OMs to OM here:
INNER JOIN [SSISDB].[internal].[operation_messages] AS OM
ON EM.operation_id = OM.operation_id 

INNER JOIN [SSISDB].[internal].[executions] AS E 
ON OM.Operation_id = E.EXECUTION_ID 

WHERE OM.Message_Type = 120 -- 120 means Error 
AND EM.event_name = 'OnError' 
-- This is something i'm not sure right now but SSIS.Pipeline just adding duplicates so I'm removing it. 
AND ISNULL(EM.subcomponent_name, '') <> 'SSIS.Pipeline' 
ORDER BY EM.operation_id DESC 