# Bible Stories: saves the Bible pictures listed in pictures.csv into the pictures folder, skipping any it already has.
param([string]$Dir = (Split-Path -Parent $MyInvocation.MyCommand.Path), [switch]$Quiet)
$ErrorActionPreference = 'Continue'
if ($Quiet) { $ProgressPreference = 'SilentlyContinue' }
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
$csv = Join-Path $Dir 'pictures.csv'
if (-not (Test-Path $csv)) { return }
$pics = Join-Path $Dir 'pictures'
New-Item -ItemType Directory -Force -Path (Join-Path $pics 'dore'), (Join-Path $pics 'schnorr') | Out-Null
$list = Import-Csv $csv
$wc = New-Object Net.WebClient
$wc.Headers.Add('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) BibleStories/1.0')
function Have($f) { (Test-Path $f) -and ((Get-Item $f).Length -gt 5000) }
function Say($t) { if (-not $Quiet) { Write-Host $t } }

# Dore engravings: the 30 MB collection is much faster than one at a time.
$needDore = @($list | Where-Object { $_.folder -eq 'dore' -and -not (Have (Join-Path $pics ('dore\' + $_.name))) })
if ($needDore.Count -gt 20) {
  Say '  Downloading the Gustave Dore engravings (about 30 MB)...'
  $tmp = Join-Path $env:TEMP 'BibleStoriesDore'
  $zip = Join-Path $env:TEMP 'BibleStoriesDore.zip'
  try {
    $wc.DownloadFile('https://www.creationism.org/images/DoreBibleIllus/DoreBibleIllusMed.zip', $zip)
    if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
    Expand-Archive -Path $zip -DestinationPath $tmp -Force
    $groups = @{}
    foreach ($f in (Get-ChildItem $tmp -Recurse -Include *.jpg, *.jpeg)) {
      if ($f.Name -cmatch '^([a-x][0-9A-Za-z]{3}\d{4,5}Dore)') {
        $code = $Matches[1]
        if (-not $groups.ContainsKey($code) -or $f.Length -gt $groups[$code].Length) { $groups[$code] = $f }
      }
    }
    foreach ($code in $groups.Keys) { Copy-Item $groups[$code].FullName (Join-Path $pics ('dore\' + $code + '.jpg')) -Force }
  } catch { Say '  Getting the pictures one at a time instead.' }
  finally { Remove-Item $zip -Force -ErrorAction SilentlyContinue; Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
}

# Anything still missing: one at a time.
$todo = @($list | Where-Object { -not (Have (Join-Path $pics ($_.folder + '\' + $_.name))) })
$i = 0
foreach ($p in $todo) {
  $i++
  if (-not $Quiet) { Write-Progress -Activity 'Saving Bible pictures' -Status ("{0} of {1}" -f $i, $todo.Count) -PercentComplete ([int]($i * 100 / [Math]::Max(1, $todo.Count))) }
  $dest = Join-Path $pics ($p.folder + '\' + $p.name)
  try { $wc.DownloadFile($p.url, $dest) } catch { Remove-Item $dest -Force -ErrorAction SilentlyContinue }
}
if (-not $Quiet) { Write-Progress -Activity 'Saving Bible pictures' -Completed }
$have = @($list | Where-Object { Have (Join-Path $pics ($_.folder + '\' + $_.name)) }).Count
Say ("  Pictures saved: {0} of {1}." -f $have, $list.Count)
