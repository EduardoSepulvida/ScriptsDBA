--Pegar query mais recentes
select top 10 TextData, DataBaseName, a.Duration, * from Traces.[dbo].Queries_Profile a where NTUserName is null and StartTime >= '2020-09-02 10:00:00' and cast(TextData as varchar (max))  like '%SELECT%C5_FILIAL%C5_NUM%C5_NOTA%C5_SERIE%C5_VEND1%C5_X%' order by a.StartTime  desc

Pegar query mais demoradas...
select    SUBSTRING(TextData, 1, 60) as obj, sum(CPU) as CPU_Total, sum(Reads) as Reads_Total, count(*) as QTD_Requests 
from    Traces..Queries_Profile 
where    StartTime > '20200701' --and    ((textdata like 'exec sp[0-9]%') or (textdata like 'exec sr[0-9]%'))
group by SUBSTRING(TextData, 1, 60) order by 4 desc  




