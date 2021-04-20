CREATE OR ALTER FUNCTION __pwt_fnc_varbinary_to_base64(@varbinary as varbinary(max))
RETURNS varchar(max)
BEGIN
	RETURN (select @varbinary as '*' for xml path(''))
END