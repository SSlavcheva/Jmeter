
param (
    [string]$TestsLogger = "TeamCityLogger"
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

. (Join-Path $PSScriptRoot "..\read_config.ps1" -Resolve)

. (Join-Path $PSScriptRoot "..\cleanup_agent.ps1" -Resolve)


& "C:\JmeterPerformanceTests\jmeter2\apache-jmeter-5.5\bin\jmeter.bat" -n -t "C:\JmeterPerformanceTests\jmeter2\apache-jmeter-5.5\bin\Perf_API2.jmx"
Write-Output "##teamcity[blockOpened name='script is run']"


# jmeter -n -t $APITestsPath\apache-jmeter-5.5\bin\Perf_API.jmx -l $APITestsPath\JMeterlogs\Report.csv

$testsExitCode = $LastExitCode

Write-Output "##teamcity[blockClosed name='Running New UI Perf Tests']"

