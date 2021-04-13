SELECT UD.Nm_Database
,UT.Nm_Table
,[Nm_Drive]
,[Nr_Total_Size] AS TOTAL
,Dt_Log
INTO #q1
FROM [Traces].[dbo].[Table_Size_History] TSH
JOIN Traces.[dbo].[User_Table] UT ON TSH.Id_Table = UT.Id_Table
JOIN Traces..User_Database UD ON UD.Id_Database = TSH.Id_Database
WHERE TSH.Id_Database = 11
AND TSH.Dt_Log >= Getdate() - 60
AND [Nr_Total_Size] > 0
ORDER BY TOTAL DESC

SELECT Nm_Database
,Nm_Table
,Dt_Log AS Data_Atual
,TOTAL AS Tamanho_Atual
,(
SELECT TOP 1 Dt_Log
FROM #q1 temp2
WHERE temp1.Nm_Table = temp2.Nm_Table
ORDER BY Dt_Log ASC
) AS DT_Antes
,(
SELECT TOP 1 TOTAL
FROM #q1 temp2
WHERE temp1.Nm_Table = temp2.Nm_Table
ORDER BY Dt_Log ASC
) AS Tamanho_Antes
,TOTAL - (
SELECT TOP 1 TOTAL
FROM #q1 temp2
WHERE temp1.Nm_Table = temp2.Nm_Table
ORDER BY Dt_Log ASC
) AS Diferenca_TOTAL
FROM #q1 temp1
WHERE Dt_Log = '20210406'
ORDER BY Diferenca_TOTAL DESC

----------------------

drop table #q1

SELECT UD.Nm_Database
,UT.Nm_Table
,[Nm_Drive]
,[Nr_Total_Size] AS TOTAL
,Dt_Log
INTO #q1
FROM [Traces].[dbo].[Table_Size_History] TSH
JOIN Traces.[dbo].[User_Table] UT ON TSH.Id_Table = UT.Id_Table
JOIN Traces..User_Database UD ON UD.Id_Database = TSH.Id_Database
WHERE TSH.Id_Database = 8
AND TSH.Dt_Log = '20210406'
AND [Nr_Total_Size] > 0


UNION ALL

SELECT UD.Nm_Database
,UT.Nm_Table
,[Nm_Drive]
,[Nr_Total_Size] AS TOTAL
,Dt_Log
FROM [Traces].[dbo].[Table_Size_History] TSH
JOIN Traces.[dbo].[User_Table] UT ON TSH.Id_Table = UT.Id_Table
JOIN Traces..User_Database UD ON UD.Id_Database = TSH.Id_Database
WHERE TSH.Id_Database = 8
AND TSH.Dt_Log = '20210405'
AND [Nr_Total_Size] > 0



SELECT Nm_Database
,Nm_Table
,Dt_Log AS Data_Atual
,TOTAL AS Tamanho_Atual
,(
SELECT TOP 1 Dt_Log
FROM #q1 temp2
WHERE temp1.Nm_Table = temp2.Nm_Table
ORDER BY Dt_Log ASC
) AS DT_Antes
,(
SELECT TOP 1 TOTAL
FROM #q1 temp2
WHERE temp1.Nm_Table = temp2.Nm_Table
ORDER BY Dt_Log ASC
) AS Tamanho_Antes
,TOTAL - (
SELECT TOP 1 TOTAL
FROM #q1 temp2
WHERE temp1.Nm_Table = temp2.Nm_Table
ORDER BY Dt_Log ASC
) AS Diferenca_TOTAL
FROM #q1 temp1
WHERE Dt_Log = '20210406'
ORDER BY Diferenca_TOTAL DESC

