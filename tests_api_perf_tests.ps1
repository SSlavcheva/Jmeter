
param (
    [string]$TestsLogger = "TeamCityLogger"
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

. (Join-Path $PSScriptRoot "..\read_config.ps1" -Resolve)

. (Join-Path $PSScriptRoot "..\cleanup_agent.ps1" -Resolve)

$createCoverageReport = $env:COVERAGE_REPORT -eq "True" -or $branchName -eq "master" -or $branchName.StartsWith("release/")
Write-Output "createCoverageReport=$createCoverageReport"

$parallelism = if ($null -eq $env:MAX_PARALLELISM) { "10" } else { $env:MAX_PARALLELISM }
Write-Output "parallelism=$parallelism"

Write-Output "##teamcity[blockOpened name='Deploying local slot']"
. (Join-Path $PSScriptRoot ".\deploy_local.ps1" -Resolve)
Write-Output "##teamcity[blockClosed name='Deploying local slot']"

Write-Output "##teamcity[blockClosed name='Restore test tenant']"
$backupShare = '\\sf-fs-01.netagesolutions.com\Sofia\Products\QA\PerformanceTesting\backup_api'
$slotRootFolder = 'C:\DynamoWebRoot\dynamo'
$tenantname = 'bop_presbyterian_church'
robocopy "$backupShare\$tenantname" "D:\TenantBackup\$tenantname" /NFL /NDL /mir /nc /ns /np
& "$slotRootFolder\slot\bin\slot.exe" `
    /SlotRootFolder:"$slotRootFolder" `
    /Action:Restore `
    /Name:$tenantname `
    /CopyAs:$tenantname `
    /BackupFolder:D:\TenantBackup `
    /SqlServerBackupFolder:C:\temp `
    /ObfuscateData:-

if ($LastExitCode -ne 0) {
    Write-Output "##teamcity[blockOpened name='Restore test tenant fail']"
    
    throw "Last command exited with code: $LastExitCode" 
}
Write-Output "##teamcity[blockClosed name='Restore test tenant']"

Write-Output "##teamcity[blockOpened name='Copying tenant configs']"
#Will publish as artifact
robocopy "$slotRootFolder\ServiceConfig\TenantConfig" "$buildPath\tenants\TenantConfig-Created"  /NFL /NDL /mir /nc /ns /np
Write-Output "##teamcity[blockClosed name='Copying tenant configs']"

$APITestsPath = "C:\JmeterPerformanceTests"
Push-Location -Path $APITestsPath
Write-Output "##teamcity[blockOpened name='Installing tests npm packages']"
yarn install --silent --no-lockfile
if ($LastExitCode -ne 0) { throw "Last command exited with code: $LastExitCode" }
Write-Output "##teamcity[blockClosed name='Installing tests npm packages']"

Write-Output "##teamcity[blockOpened name='Running Jmeter API Tests start']"

$coverage = "--no--coverage"
if ($createCoverageReport) {
    $coverage = "--coverage"
}

#node "start_perf_tests.js" --parallelism $parallelism --slotRootFolder "$slotRootFolder" --logger "$TestsLogger" $coverage
# Jmeter trigger

#$JMeterPath = "$sourcePath\AutomationTesting\JmeterPerformanceTests\jmeter\bin\jmeter.bat"
#Write-Output "##teamcity[blockOpened name='found .bat']"
#$TestPlanPath = "$sourcePath\AutomationTesting\JmeterPerformanceTests\jmeter\bin\Perf_API.jmx"
#Write-Output "##teamcity[blockOpened name='found Perf_API']"

#Write-Output "##teamcity[blockOpened name='prepare to run script']"

#& "C:\JmeterPerformanceTests\jmeter\bin\jmeter.bat" -n -t "C:\JmeterPerformanceTests\jmeter\bin\Perf_API.jmx"
#Write-Output "##teamcity[blockOpened name='script is run']"

& "C:\JmeterPerformanceTests\jmeter2\apache-jmeter-5.5\bin\jmeter.bat" -n -t "C:\JmeterPerformanceTests\jmeter2\apache-jmeter-5.5\bin\Perf_API2.jmx"
Write-Output "##teamcity[blockOpened name='script is run']"


# jmeter -n -t $APITestsPath\apache-jmeter-5.5\bin\Perf_API.jmx -l $APITestsPath\JMeterlogs\Report.csv

$testsExitCode = $LastExitCode

Write-Output "##teamcity[blockClosed name='Running New UI Perf Tests']"

Pop-Location
    
robocopy "$slotRootFolder\perflog" "$buildPath\perflog" /NFL /NDL /mir /nc /ns /np

&"$err_aggregate" "$buildPath\perflog" "$buildPath\perflog\aggregated"

Write-Output "##teamcity[blockOpened name='Copying tenant configs after test']"
#Will publish as artifact
robocopy "$slotRootFolder\ServiceConfig\TenantConfig" "$buildPath\tenants\TenantConfig-Tested"  /NFL /NDL /mir /nc /ns /np
Write-Output "##teamcity[blockClosed name='Copying tenant configs after test']"

if ($createCoverageReport) {
    Write-Output "##teamcity[blockOpened name='Exporting coverage report']"

    node "coverage.js"

    robocopy "Web UI/Dynamo6/Dynamo6Web3/Dynamo6Web3/tests/coverage/combined" "./build/newui_coverage"  /NFL /NDL /mir /nc /ns /np
    
    Write-Output "##teamcity[blockClosed name='Exporting coverage report']"
}

if ($testsExitCode -ne 0) { throw "Last command exited with code: $LastExitCode" }


Write-Host "Insert record in DB"
$DatabaseServer = "DYNAMOSQL3\SQL2019"
$DatabaseSchema = "testresults" 
$DatabaseUser = "profiler"
$DatabasePass = "profiler"

$SqlConnection = New-Object System.Data.SqlClient.SqlConnection
$SqlConnection.ConnectionString = "Data Source=$DatabaseServer;Initial Catalog=$DatabaseSchema;User Id=$DatabaseUser;Password=$DatabasePass" 
$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
#$SqlCmd.CommandText = "BULK INSERT testresults.dbo.PerformanceAPISummaryReport FROM '\\sf-fs-01.netagesolutions.com\Sofia\Products\QA\PerformanceTesting\JmeterResults\Result.csv' WITH (FIELDTERMINATOR = ',', ROWTERMINATOR = '\n',FIRSTROW = 2);"

$SqlCmd.CommandText = @"
BULK INSERT testresults.dbo.PerformanceAPISummaryReport 
FROM '\\sf-fs-01.netagesolutions.com\Sofia\Products\QA\PerformanceTesting\JmeterResults\Result.csv'
WITH (FIELDTERMINATOR = ',', ROWTERMINATOR = '\n', FIRSTROW = 2);
"@


$SqlCmd.Connection = $SqlConnection 
$SqlConnection.Open()
$SqlCmd.ExecuteNonQuery()
$SqlConnection.Close()

Write-Host "Done"

