
& "C:\Users\Sylvia\Documents\jmeter2\jmeterproject\apache-jmeter-5.5\bin\jmeter.bat" -n -t "C:\Users\Sylvia\Documents\jmeter2\jmeterproject\apache-jmeter-5.5\bin\test1.jmx" -l "C:\Users\Sylvia\Downloads\buildAgentFull\work\b74038a8e1f1354f\Results\Logs.jtl"







Write-Output "##teamcity[blockOpened name='script is run']"

param(
[string]$source,
[string]$destination
)

$source="C:\Users\Sylvia\Downloads\buildAgentFull\work\b74038a8e1f1354f\Results\Logs.jtl"
$destination="C:\Users\Sylvia\Downloads\buildAgentFull\work\b74038a8e1f1354f\Results\Logs2.jtl"

$reader = [System.IO.File]::OpenText($source)
$writer = New-Object System.IO.StreamWriter $destination
for(;;) {
$line = $reader.ReadLine()
if ($null -eq $line) {
break
}
$data = $line.Split("t") $writer.WriteLine("{0}t{1}t{2}t{3}t{4}t{5}t{6}t{7}",
$data[0],
$data[1],
$data[2],
$data[7],
$data[3],
$data[4],
$data[5],
$data[6])
}
$reader.Close()
$writer.Close()




