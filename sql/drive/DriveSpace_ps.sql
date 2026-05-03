-- =============================================================================
-- Drive Space Report via PowerShell (xp_cmdshell)
-- Queries Win32_Volume via PowerShell and parses XML output in SQL
-- Shows free space and capacity per volume in MB
-- =============================================================================

DECLARE @XML_string varchar(max);           -- Holds concatenated XML string
DECLARE @DriveSpace XML;                    -- Parsed XML object
DECLARE @XML TABLE (
    XMLitself varchar(2000),
    orderIt int IDENTITY(1,1) PRIMARY KEY   -- Preserves xp_cmdshell output order
);

-- Execute PowerShell to get drive space info, output as XML string
-- Get-CimInstance is preferred over deprecated Get-WmiObject (PS 5.1+)
INSERT INTO @XML(XMLitself)
EXEC xp_cmdshell 'powershell.exe -noprofile -command "Get-CimInstance Win32_Volume -ErrorAction ''Stop'' | Select-Object @{Label=''Name'';Expression={$_.Name+'' - ''+$_.Label}},@{Label=''freeSpaceMB'';Expression={$_.FreeSpace/1MB}}, @{Label=''capacityMB'';Expression={$_.Capacity/1MB}} | ConvertTo-XML -As String"';

-- Concatenate XML rows in correct order (ORDER BY orderIt preserves output sequence)
SELECT @XML_string = COALESCE(@XML_string, '') + XMLitself
FROM @XML
WHERE XMLitself IS NOT NULL
ORDER BY orderIt;  -- FIX: was missing ORDER BY, which could scramble XML

SELECT @DriveSpace = @XML_string;

-- Pivot XML properties into columns: volume letter, free space, capacity
SELECT
    MAX(CASE WHEN attribute = 'Name' THEN value ELSE '' END) AS volLetter,
    CAST(MAX(CASE WHEN attribute = 'freeSpaceMB' THEN value ELSE NULL END) AS decimal(15,3)) AS freeSpaceMB,
    CAST(MAX(CASE WHEN attribute = 'capacityMB' THEN value ELSE NULL END) AS decimal(15,3)) AS capacityMB
FROM (
    SELECT
        [property].value('(./text())[1]', 'varchar(200)') AS [value],
        [property].value('@Name', 'varchar(200)') AS [attribute],
        DENSE_RANK() OVER (ORDER BY [object]) AS unique_object
    FROM @DriveSpace.nodes('Objects/Object') AS b([object])
    CROSS APPLY b.object.nodes('./Property') AS c(property)
) PowerShell
GROUP BY unique_object;
