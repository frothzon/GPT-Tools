[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $GmtoolArgs
)

$toolRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourceRoot = Join-Path $toolRoot "src"
$env:PYTHONUTF8 = "1"

if ($env:PYTHONPATH) {
    $env:PYTHONPATH = "$sourceRoot;$env:PYTHONPATH"
}
else {
    $env:PYTHONPATH = $sourceRoot
}

$pythonLauncher = Get-Command py.exe -ErrorAction SilentlyContinue
if (-not $pythonLauncher) {
    Write-Error "Python 3.11 or newer is required. The Windows 'py' launcher was not found."
    exit 127
}

& $pythonLauncher.Source -3 -m gmtool @GmtoolArgs
exit $LASTEXITCODE
