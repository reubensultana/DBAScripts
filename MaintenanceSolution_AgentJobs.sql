-- Source: http://ola.hallengren.com

DatabaseBackup - SYSTEM_DATABASES - FULL
sqlcmd -E -S $(ESCAPE_SQUOTE(SRVR)) -d db_dba -Q "EXECUTE [dbo].[DatabaseBackup] @Databases = 'SYSTEM_DATABASES', @Directory = N'E:\MSSQL2K5\MSSQL.1\MSSQL\BACKUP', @BackupType = 'FULL', @Verify = 'Y', @CleanupTime = NULL, @CheckSum = 'Y', @LogToTable = 'Y'" -b
D:\MSSQL2K5\MSSQL.1\MSSQL\LOG\DatabaseBackup_$(ESCAPE_SQUOTE(JOBID))_$(ESCAPE_SQUOTE(STEPID))_$(ESCAPE_SQUOTE(STRTDT))_$(ESCAPE_SQUOTE(STRTTM)).txt

DatabaseBackup - USER_DATABASES - FULL
sqlcmd -E -S $(ESCAPE_SQUOTE(SRVR)) -d db_dba -Q "EXECUTE [dbo].[DatabaseBackup] @Databases = 'USER_DATABASES', @Directory = N'E:\MSSQL2K5\MSSQL.1\MSSQL\BACKUP', @BackupType = 'FULL', @Verify = 'Y', @CleanupTime = NULL, @CheckSum = 'Y', @LogToTable = 'Y'" -b
D:\MSSQL2K5\MSSQL.1\MSSQL\LOG\DatabaseBackup_$(ESCAPE_SQUOTE(JOBID))_$(ESCAPE_SQUOTE(STEPID))_$(ESCAPE_SQUOTE(STRTDT))_$(ESCAPE_SQUOTE(STRTTM)).txt



DatabaseBackup - USER_DATABASES - LOG
sqlcmd -E -S $(ESCAPE_SQUOTE(SRVR)) -d db_dba -Q "EXECUTE [dbo].[DatabaseBackup] @Databases = 'USER_DATABASES', @Directory = N'E:\MSSQL2K5\MSSQL.1\MSSQL\BACKUP', @BackupType = 'LOG', @Verify = 'Y', @CleanupTime = NULL, @CheckSum = 'Y', @LogToTable = 'Y'" -b
D:\MSSQL2K5\MSSQL.1\MSSQL\LOG\DatabaseBackup_$(ESCAPE_SQUOTE(JOBID))_$(ESCAPE_SQUOTE(STEPID))_$(ESCAPE_SQUOTE(STRTDT))_$(ESCAPE_SQUOTE(STRTTM)).txt


sqlcmd -E -S $(ESCAPE_SQUOTE(SRVR)) -d db_dba -Q "EXECUTE [dbo].[IndexOptimize] @Databases = 'USER_DATABASES', @FragmentationLow = NULL, @FragmentationMedium = 'INDEX_REORGANIZE,INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE', @FragmentationHigh = 'INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE', @FragmentationLevel1 = 5, @FragmentationLevel2 = 30, @PageCountLevel = 1000, @SortInTempdb='Y', @MaxDOP = 1, @FillFactor=85, @UpdateStatistics = 'ALL', @OnlyModifiedStatistics = 'Y', @StatisticsSample = 25, @TimeLimit = 28800, @Execute = 'Y';" -b
D:\MSSQL2K5\MSSQL.1\MSSQL\LOG\IndexOptimize_$(ESCAPE_SQUOTE(JOBID))_$(ESCAPE_SQUOTE(STEPID))_$(ESCAPE_SQUOTE(STRTDT))_$(ESCAPE_SQUOTE(STRTTM)).txt


sqlcmd -E -S $(ESCAPE_SQUOTE(SRVR)) -d db_dba -Q "EXECUTE [dbo].[IndexOptimize] @Databases = 'USER_DATABASES', @FragmentationLow = NULL, @FragmentationMedium = NULL, @FragmentationHigh = NULL, @UpdateStatistics = 'ALL', @OnlyModifiedStatistics = 'Y';" -b
D:\MSSQL2K5\MSSQL.1\MSSQL\LOG\IndexOptimize_$(ESCAPE_SQUOTE(JOBID))_$(ESCAPE_SQUOTE(STEPID))_$(ESCAPE_SQUOTE(STRTDT))_$(ESCAPE_SQUOTE(STRTTM)).txt



Output File Cleanup
cmd /q /c "For /F "tokens=1 delims=" %v In ('ForFiles /P "D:\MSSQL2K5\MSSQL.1\MSSQL\LOG" /m *_*_*_*.txt /d -30 2^>^&1') do if EXIST "D:\MSSQL2K5\MSSQL.1\MSSQL\LOG"\%v echo del "D:\MSSQL2K5\MSSQL.1\MSSQL\LOG"\%v& del "D:\MSSQL2K5\MSSQL.1\MSSQL\LOG"\%v"
D:\MSSQL2K5\MSSQL.1\MSSQL\LOG\OutputFileCleanup_$(ESCAPE_SQUOTE(JOBID))_$(ESCAPE_SQUOTE(STEPID))_$(ESCAPE_SQUOTE(STRTDT))_$(ESCAPE_SQUOTE(STRTTM)).txt

sp_delete_backuphistory
sqlcmd -E -S $(ESCAPE_SQUOTE(SRVR)) -d msdb -Q "DECLARE @CleanupDate datetime; SET @CleanupDate = DATEADD(dd,-30,GETDATE()); EXECUTE dbo.sp_delete_backuphistory @oldest_date = @CleanupDate" -b
D:\MSSQL2K5\MSSQL.1\MSSQL\LOG\sp_delete_backuphistory_$(ESCAPE_SQUOTE(JOBID))_$(ESCAPE_SQUOTE(STEPID))_$(ESCAPE_SQUOTE(STRTDT))_$(ESCAPE_SQUOTE(STRTTM)).txt

sp_purge_jobhistory
sqlcmd -E -S $(ESCAPE_SQUOTE(SRVR)) -d msdb -Q "DECLARE @CleanupDate datetime; SET @CleanupDate = DATEADD(dd,-30,GETDATE()); EXECUTE dbo.sp_purge_jobhistory @oldest_date = @CleanupDate" -b
D:\MSSQL2K5\MSSQL.1\MSSQL\LOG\sp_purge_jobhistory_$(ESCAPE_SQUOTE(JOBID))_$(ESCAPE_SQUOTE(STEPID))_$(ESCAPE_SQUOTE(STRTDT))_$(ESCAPE_SQUOTE(STRTTM)).txt

CommandLog Cleanup
sqlcmd -E -S $(ESCAPE_SQUOTE(SRVR)) -d db_dba -Q "DELETE FROM [dbo].[CommandLog] WHERE StartTime < DATEADD(dd,-30,GETDATE())" -b
D:\MSSQL2K5\MSSQL.1\MSSQL\LOG\CommandLogCleanup_$(ESCAPE_SQUOTE(JOBID))_$(ESCAPE_SQUOTE(STEPID))_$(ESCAPE_SQUOTE(STRTDT))_$(ESCAPE_SQUOTE(STRTTM)).txt
