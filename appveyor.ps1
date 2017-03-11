echo "Downloading dmd...";
Invoke-WebRequest "http://downloads.dlang.org/releases/2.x/$env:DVersion/dmd.$env:DVersion.windows.7z" -OutFile c:\dmd.7z;
7z x c:\dmd.7z -oc:\ > $null;
echo "Downloading dub...";
Invoke-WebRequest https://code.dlang.org/files/dub-1.0.0-beta.1-windows-x86.zip -OutFile c:\dub.zip;
7z x c:\dub.zip -oc:\dub > $null;

if ($env:arch -eq "x86") {
  echo "Downloading 32-bit LLVM...";
  Invoke-WebRequest http://llvm.org/releases/3.8.1/LLVM-3.8.1-win32.exe -OutFile c:\LLVM.exe;
  7z x c:\LLVM.exe -oc:\PROGRA~2\LLVM > $null;
}

$env:PATH = "c:\dub;$($env:PATH)";
$env:PATH = "c:\dmd2\windows\bin;$($env:PATH)";

$env:compilersetup = "C:\Program Files (x86)\Microsoft Visual Studio 14.0\VC\vcvarsall";

if ($env:arch -eq "x86") {
  $env:compilersetupargs = "x86";
  $env:PATH = "c:\PROGRA~2\LLVM\bin;$($env:PATH)";
  $env:archswitch = "";
}
else {
  $env:compilersetupargs = "amd64";
  $env:archswitch = "--arch=x86_64";
}

dub --version;
dmd --version;

echo "Setting up compiler toolchain...";

function Invoke-CmdScript {
  param([string] $script, [string] $param);

  $tempFile = [IO.Path]::GetTempFileName();
  cmd /c "`"$script`" $params && set > `"$tempFile`" ";

  Get-Content $tempFile | Foreach-Object {
    if ($_ -match "^(.*?)=(.*)$") {
        Set-Content "env:\$($matches[1])" $matches[2];
    }
  }

  Remove-Item $tempFile;
}

Invoke-CmdScript $env:compilersetup $env:compilersetupargs;

echo "Building dstep...";
dub build $env:archswitch;

if ($LastExitCode -ne 0) {
  $host.SetShouldExit(-1)
}

echo "Running tests...";
dub --config=test $env:archswitch;

if ($LastExitCode -ne 0) {
  $host.SetShouldExit(-1)
}
