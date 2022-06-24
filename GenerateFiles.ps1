[CmdletBinding()]
param (
    [Parameter(Mandatory)][string]$SettingsFilePath
)

$settings = gc $SettingsFilePath | ConvertFrom-Json;

#lists all databases on the server that are not a replica
$query = "SELECT DatabaseName = d.[name], ServerName = '{0}'
FROM sys.databases d
WHERE NOT EXISTS (SELECT * FROM sys.dm_hadr_database_replica_states x WHERE x.is_local = 1 AND x.is_primary_replica = 0 AND x.database_id = d.database_id)
    AND d.[name] NOT IN ('tempdb','model','msdb')
    AND d.[name] NOT IN ($("'"+($settings.excludes -Join "','")+"'"))"

#run the query on every server
write 'Get list of databases from all servers';
$dblist = $settings.servers | % -Parallel { Invoke-DbaQuery -SqlInstance $_ -Database master -Query ($using:query -f $_) } -ThrottleLimit 5
###############################################################

###############################################################
$final = @();
foreach ($item in $settings.groups) {
    $src_dbs = $dblist | ? ServerName -EQ $item.source;
    $tgt_dbs = $dblist | ? ServerName -EQ $item.dest;

    foreach ($dbs in $src_dbs) {
        if ($tgt_dbs | ? DatabaseName -eq $dbs.DatabaseName) {
            $final += [PSCustomObject]@{
                SrcSvr = $item.source;
                TgtSvr = $item.dest;
                DBName = $dbs.DatabaseName;
                FileName = "$($item.source)_$($item.dest).$($dbs.DatabaseName).scmp"
            }
        }
    }
}
###############################################################

###############################################################
#import template file
write 'Import Schmea compare template file';
$data = Get-Content -Path .\FROM_TO.DATABASE.scmp -Raw

#create directory if it doesn't exist
write 'Create directory if it doesnt exist';
New-Item -Name Compare -ItemType Directory -Force > $null

#empty directory
write 'Clear out the directory';
gci .\Compare | rm

#export template file with variables replaced, looping through all combiations
write 'Generate all Schema compare files';
$final | % {
    $filename = $_.FileName;
    $data -replace '%%SOURCE_SERVER%%',$_.SrcSvr -replace '%%TARGET_SERVER%%',$_.TgtSvr -replace '%%DATABASE%%',$_.DBName | Out-File -FilePath .\Compare\$filename
}
