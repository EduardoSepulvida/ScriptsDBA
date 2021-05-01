USE TRACES
GO


SELECT 
	MIN(STARTTIME),MAX(STARTTIME),DATEDIFF(SECOND,MIN(STARTTIME),MAX(STARTTIME) ), count(1)
FROM Trace_20210429_1702
WHERE CAST(TextData AS NVARCHAR(MAX)) NOT LIKE N'exec sp_reset_connectioN'


SELECT 
	* 
FROM Trace_20210429_1702
WHERE CAST(TextData AS NVARCHAR(MAX)) NOT LIKE N'exec sp_reset_connectioN'
--AND CAST(TextData AS NVARCHAR(MAX))  LIKE N'%@AuthorizationId%'
ORDER BY CPU DESC

--exec sp_executesql N'SELECT  [Id],[AuthorizationId],[BalanceId],[AgreementName],[Document],[Date],[ExpirationDate],[InvoiceId],[Result],[IsConfirmed],[Amount],[IsOver],[ExeededValue],[CreditReasonId],[CreditValidAt],[Severity],[Blocked],[Rating],[Score],[CloseOutDays],[HasExpiredInvoices],[AmountExpired],[OrderReference],[CreditLimit],[ValueTaken],[DaysOverdue],[Status],[CreditLimitPlus],[EconomicGroupParentId],[PersonType],[OrderId],[SellerName],[ReferenceCode],[CanIntegrate],[Splitted],[ExtendedDate]   FROM [dbo].[Authorization] WITH (NOLOCK)  WHERE [AuthorizationId] = @AuthorizationId',N'@AuthorizationId nvarchar(4000)',=N'60894042571c120001e54ac3'



SELECT 
	SUM(CPU)CPU,COUNT(1)QTD
FROM Trace_20210429_1702
WHERE CAST(TextData AS NVARCHAR(MAX)) LIKE N'%PR_SELECT_CREDITLIMIT_BY_DOCUMENT%'
AND CAST(TextData AS NVARCHAR(MAX)) NOT LIKE N'exec sp_reset_connectioN'


SELECT 
	*
FROM Trace_20210429_1702
WHERE CAST(TextData AS NVARCHAR(MAX)) LIKE N'%PR_SELECT_CREDITLIMIT_BY_DOCUMENT%'
AND CAST(TextData AS NVARCHAR(MAX)) NOT LIKE N'exec sp_reset_connectioN'
ORDER BY CPU DESC


SELECT 
	SUM(CPU)CPU,COUNT(1)QTD
FROM Trace_20210429_1702
WHERE CAST(TextData AS NVARCHAR(MAX)) NOT LIKE N'%PR_SELECT_CREDITLIMIT_BY_DOCUMENT%'
AND CAST(TextData AS NVARCHAR(MAX)) NOT LIKE N'exec sp_reset_connectioN'





SELECT 
	substring(CAST(TextData AS NVARCHAR(MAX)),1,30), SUM(CPU)CPU_SUM,AVG(CPU)CPU_AVG,COUNT(1)QTD
FROM Trace_20210429_1702
WHERE 1=1
--and CAST(TextData AS NVARCHAR(MAX)) LIKE N'%PR_SELECT_CREDITLIMIT_BY_DOCUMENT%'
AND CAST(TextData AS NVARCHAR(MAX)) NOT LIKE N'exec sp_reset_connectioN'
group by substring(CAST(TextData AS NVARCHAR(MAX)),1,30)
order by 2 desc
