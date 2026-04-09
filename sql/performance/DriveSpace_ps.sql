DECLARE @XML_string varchar(max)
DECLARE @DriveSpace XML
DECLARE @XML TABLE (XMLitself varchar(2000), orderIt int IDENTITY(1,1) PRIMARY KEY);

INSERT INTO @XML(XMLitself)
EXEC xp_cmdshell 'powershell.exe -noprofile -command "Get-WmiObject Win32_Volume -ErrorAction ''Stop'' | Select-Object @{Label=''Name'';Expression={$_.Name+'' - ''+$_.Label}},@{Label=''freeSpaceMB'';Expression={$_.FreeSpace/1MB}}, @{Label=''capacityMB'';Expression={$_.Capacity/1MB}} | ConvertTo-XML -As string"'

SELECT @XML_string = COALESCE(@XML_string,'') + XMLitself
FROM @XML
WHERE XMLitself IS NOT NULL

SELECT @DriveSpace = @XML_string

SELECT MAX(CASE WHEN attribute='Name' THEN value ELSE '' END) AS volLetter
    ,CAST(MAX(CASE WHEN attribute='freeSpaceMB' THEN value ELSE '' END) AS decimal(15,3)) AS freeSpaceMB
    ,CAST(MAX(CASE WHEN attribute='capacityMB' THEN value ELSE '' END) AS decimal(15,3)) AS capacityMB
    --,@dateCreated
FROM (
    SELECT [property].value('(./text())[1]','varchar(200)') AS [value],
        [property].value('@Name','varchar(200)') AS [attribute],
        DENSE_RANK() OVER (ORDER BY [object]) AS unique_object
    FROM @DriveSpace.nodes('Objects/Object') AS b([object])
    CROSS APPLY b.object.nodes('./Property') AS c(property)
    ) PowerShell
GROUP BY unique_object;
