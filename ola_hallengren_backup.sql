EXECUTE dbo.DatabaseBackup
@Databases = 'USER_DATABASES',
@Directory = 'C:\Backup',
@BackupType = 'FULL',
@DirectoryStructure = NULL,
@AvailabilityGroupDirectoryStructure = NULL,
@CheckSum = 'Y',
@Compress = 'Y';
