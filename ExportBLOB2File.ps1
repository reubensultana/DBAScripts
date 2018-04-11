## Export of "larger" Sql Server Blob to file with GetBytes-Stream.
# Configuration data
param([String]$ServerName="localhost",          # SQL Server Instance.
      [String]$Database="AdventureWorks2012",   # Database Name
      [String]$ObjectName="Production.Document",# Object Name (table or view)
      [String]$KeyColumnName="DocumentNode",    # Key column name
      [String]$BinaryColumnName="Document",     # Binary column name
      [String]$OutputFileType=".pdf",           # Output file type (e.g. ".pdf", ".doc", ".jpg", etc.)
      [String]$KeyColumnFilter="0",             # Key column name
      [String]$DestinationFolder="C:\TEMP\")    # Path to export to.

# Usage: .\ExportBLOB2File.ps1 -ServerName "localhost" -Database "AdventureWorks2012" -ObjectName "Production.Document" -KeyColumnName "DocumentNode" -BinaryColumnName "Document" -OutputFileType ".pdf" -KeyColumnFilter "0" -DestinationFolder "C:\TEMP\"

$bufferSize = 8192;               # Stream buffer size in bytes.
# Select-Statement for name & blob
# with filter.
$Sql = "SELECT CAST($KeyColumnName AS varchar(10)) + '$OutputFileType', $BinaryColumnName FROM $ObjectName WHERE $KeyColumnName = $KeyColumnFilter";

# "Retrieving results for query:"
# "$Sql"

# Open ADO.NET Connection
$con = New-Object Data.SqlClient.SqlConnection;
$con.ConnectionString = "Data Source=$ServerName;Integrated Security=True;Initial Catalog=$Database";
$con.Open();

# New Command and Reader
$cmd = New-Object Data.SqlClient.SqlCommand $Sql, $con;
$rd = $cmd.ExecuteReader();

# Create a byte array for the stream.
$out = [array]::CreateInstance('Byte', $bufferSize)

# Looping through records
While ($rd.Read())
{
    Write-Output ("Exporting: {0}" -f $rd.GetString(0));
    # New BinaryWriter
    $fs = New-Object System.IO.FileStream ($DestinationFolder + $rd.GetString(0)), Create, Write;
    $bw = New-Object System.IO.BinaryWriter $fs;

    $start = 0;
    # Read first byte stream
    $received = $rd.GetBytes(1, $start, $out, 0, $bufferSize - 1);
    While ($received -gt 0)
    {
       $bw.Write($out, 0, $received);
       $bw.Flush();
       $start += $received;
       # Read next byte stream
       $received = $rd.GetBytes(1, $start, $out, 0, $bufferSize - 1);
    }

    $bw.Close();
    $fs.Close();
}

# Closing & Disposing all objects
$fs.Dispose();
$rd.Close();
$cmd.Dispose();
$con.Close();

Write-Output ("Finished");
RETURN
