Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSDefaultParameterValues['*:ErrorAction'] = 'Stop'

$appName="dstep"
$targetDir="bin"
$targetPath="$targetDir/$appName.exe"

function Build
{
  dub build -b release --verror --arch=$env:arch --compiler=$env:DC
}

function TestDstep
{
  dub -c test-functional --verror --arch=$env:arch --compiler=$env:DC
}

function Version
{
  Invoke-Expression "$targetPath --version"
}

function Arch
{
  if ($env:PLATFORM -eq 'x86') { '32' } else { '64' }
}

function ReleaseName
{
  "$appName-$(Version)-win$(Arch)"
}

function Archive
{
  7z a "$(ReleaseName).7z" "$targetPath"
}

Build
TestDstep
Archive
