# Bible Stories: check GitHub for a newer version, then open it in its own window.
# If this PC can't reach the internet, it just opens the copy it already has.
$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference    = 'SilentlyContinue'
$dir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$html  = Join-Path $dir 'Bible Stories.html'
$bfile = Join-Path $dir 'build.txt'
$url   = Get-Content (Join-Path $dir 'update-url.txt') -TotalCount 1
$updated = $false
if ($url) {
  try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $v = (Invoke-WebRequest -Uri ($url + 'version.json?t=' + [DateTime]::UtcNow.Ticks) -UseBasicParsing -TimeoutSec 4).Content | ConvertFrom-Json
    $have = [int64]0; if (Test-Path $bfile) { [int64]::TryParse((Get-Content $bfile -TotalCount 1), [ref]$have) | Out-Null }
    if ([int64]$v.build -gt $have) {
      $tmp = Join-Path $env:TEMP ('bible-stories-' + $v.build + '.html')
      Invoke-WebRequest -Uri ($url + 'Bible-Stories.html?t=' + [DateTime]::UtcNow.Ticks) -OutFile $tmp -UseBasicParsing -TimeoutSec 180
      # only swap it in if the whole file came down and it's the right build
      if ((Test-Path $tmp) -and (Get-Item $tmp).Length -gt 1000000 -and (Select-String -Path $tmp -SimpleMatch ('window.BS_BUILD = ' + $v.build + ';') -Quiet)) {
        $ptmp = Join-Path $env:TEMP 'bible-stories-pictures.csv'
        Invoke-WebRequest -Uri ($url + 'pictures.csv?t=' + [DateTime]::UtcNow.Ticks) -OutFile $ptmp -UseBasicParsing -TimeoutSec 30
        if ((Test-Path $ptmp) -and (Get-Item $ptmp).Length -gt 100) { Copy-Item $ptmp (Join-Path $dir 'pictures.csv') -Force }
        Remove-Item $ptmp -Force
        foreach ($f in @($v.files)) { if (-not $f) { continue }
          $ftmp = Join-Path $env:TEMP ('bible-stories-' + $f)
          Invoke-WebRequest -Uri ($url + $f + '?t=' + [DateTime]::UtcNow.Ticks) -OutFile $ftmp -UseBasicParsing -TimeoutSec 60
          if ((Test-Path $ftmp) -and (Get-Item $ftmp).Length -gt 100) { Copy-Item $ftmp (Join-Path $dir $f) -Force }
          Remove-Item $ftmp -Force }
        Copy-Item $tmp $html -Force
        Set-Content -Path $bfile -Value $v.build
        $updated = $true
      }
      Remove-Item $tmp -Force
    }
  } catch {}
}
$bases = @(${env:ProgramFiles(x86)}, $env:ProgramFiles, $env:LOCALAPPDATA) | Where-Object { $_ }
$apps  = @('Microsoft\Edge\Application\msedge.exe', 'Google\Chrome\Application\chrome.exe')
$browser = $null
foreach ($a in $apps) { foreach ($b in $bases) { $c = Join-Path $b $a; if (-not $browser -and (Test-Path $c)) { $browser = $c } } }
$uri = ([System.Uri]$html).AbsoluteUri
if ($browser) { Start-Process -FilePath $browser -ArgumentList ('--app="' + $uri + '"', '--window-size=900,1000') } else { Start-Process $html }
# after opening: quietly save any pictures this PC doesn't have yet (new ones from an update, or ones that failed before)
& (Join-Path $dir 'get-pictures.ps1') -Dir $dir -Quiet
