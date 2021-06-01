$dbNames=Invoke-SqlCmd -Query "SELECT Name FROM sys.databases where Name not in('master','msdb','model','tempdb','Traces') AND state_desc ='ONLINE'"

foreach( $dbName in $dbNames )
{
Invoke-SqlCmd -InputFile C:\Temp\t3.sql -Database $dbName.Name

}
