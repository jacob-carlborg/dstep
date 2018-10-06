Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSDefaultParameterValues['*:ErrorAction'] = 'Stop'

function Get-LatestVersion($url)
{
  (Invoke-WebRequest $url).toString().replace("`n","").replace("`r","")
}

function ResolveLatestDMD
{
  $version = $env:DVersion

  if ($version -eq 'stable')
  {
    $version = Get-LatestVersion('http://downloads.dlang.org/releases/LATEST')
    $url = "http://downloads.dlang.org/releases/2.x/$version/dmd.$version.windows.7z"
  }
  elseif ($version -eq 'beta')
  {
    $version = Get-LatestVersion('http://downloads.dlang.org/pre-releases/LATEST')
    $latestVersion = $latest.split("-")[0].split("~")[0]
    $url = "http://downloads.dlang.org/pre-releases/2.x/$latestVersion/dmd.$version.windows.7z"
  }
  elseif ($version -eq 'nightly')
  {
    $url = 'http://nightlies.dlang.org/dmd-master-2017-05-20/dmd.master.windows.7z'
  }
  else
  {
    $url = "http://downloads.dlang.org/releases/2.x/$version/dmd.$version.windows.7z"
  }

  $bin_path = "/dmd2/windows/bin"
  $env:PATH += ";$bin_path"

  $url, $bin_path
}

function Get-LatestLDCVersion($latest)
{
  Get-LatestVersion("https://ldc-developers.github.io/$latest")
}

function ResolveLatestLDC
{
  $version = $env:DVersion

  if ($version -eq 'stable')
  {
    $version = Get-LatestLDCVersion('LATEST')
  }
  elseif ($version -eq 'beta')
  {
    $version = Get-LatestLDCVersion('LATEST_BETA')
  }

  $bin_path = "/ldc2-$version-windows-$env:PLATFORM/bin"
  $url = 'https://github.com/ldc-developers/ldc/releases/download/' `
    + "v$version/ldc2-$version-windows-$env:PLATFORM.7z"

  $env:PATH += ";$bin_path"

  $url, $bin_path
}

function SetUpDCompiler
{
  if ($env:d -eq 'dmd')
  {
    $url, $bin_path = ResolveLatestDMD
    $env:DC = 'dmd'
  }
  elseif ($env:d -eq 'ldc')
  {
    $url, $bin_path = ResolveLatestLDC
    $env:DC = 'ldc2'
  }
  else
  {
    echo "Unrecognized compiler $env:d"
    $host.SetShouldExit(-1)
    return
  }

  echo "Downloading ..."
  echo "$url"
  Invoke-WebRequest "$url" -OutFile /dc.7z
  echo 'Finished'
  7z x /dc.7z -o/ > $null
  cp "$bin_path/libcurl.dll" .
}

SetUpDCompiler
