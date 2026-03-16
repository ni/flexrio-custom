param(
  [switch]$ValidateOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-TopFiles {
  param([string]$Root)

  Get-ChildItem -Path (Join-Path $Root 'targets') -Filter '*.vhd' -Recurse -File |
    Where-Object { $_.FullName -match '\\targets\\[^\\]+custom\\rtl-lvfpga\\[^\\]+\.vhd$' } |
    Where-Object {
      Select-String -Path $_.FullName -SimpleMatch 'TheLvWindowWrapper: TheLvWindowFlatWrapper' -Quiet
    } |
    Sort-Object FullName
}

function Add-PortItem {
  param(
    [System.Collections.Generic.List[object]]$Items,
    [System.Collections.Generic.List[string]]$DesiredPorts,
    [string]$Declaration,
    [string]$PkgPath
  )

  if ($Declaration -match '^(?<name>\w+)\s*:\s*(?<rest>.+?);\s*$') {
    $portName = $Matches['name']
    $comment = '--' + $Matches['rest']
  }
  elseif ($Declaration -match '^(?<name>\w+)\s*:\s*(?<rest>.+)$') {
    $portName = $Matches['name']
    $comment = '--' + $Matches['rest']
  }
  else {
    throw "Unable to parse port declaration '$Declaration' in $PkgPath"
  }

  $Items.Add([pscustomobject]@{
    Kind = 'Port'
    Name = $portName
    Comment = $comment
  })
  $DesiredPorts.Add($portName)
}

function Get-PackageInfo {
  param([string]$PkgPath)

  $lines = Get-Content -Path $PkgPath
  $componentIndex = -1
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s*component\s+TheLvWindowFlatWrapper\s+is\s*$') {
      $componentIndex = $i
      break
    }
  }

  if ($componentIndex -lt 0) {
    throw "Unable to find component declaration in $PkgPath"
  }

  $portStart = -1
  for ($i = $componentIndex; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s*port\s*\(\s*$') {
      $portStart = $i + 1
      break
    }
  }

  if ($portStart -lt 0) {
    throw "Unable to find component port list in $PkgPath"
  }

  $items = New-Object System.Collections.Generic.List[object]
  $desiredPorts = New-Object System.Collections.Generic.List[string]
  $declLines = New-Object System.Collections.Generic.List[string]
  $skipDepth = 0
  $hasIncludeTargetIo = $false

  for ($i = $portStart; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]

    if ($declLines.Count -gt 0) {
      if ($line -match '^\s*\)\s*;\s*$') {
        $decl = (($declLines | ForEach-Object { $_.Trim() }) -join ' ') -replace '\s+', ' '
        Add-PortItem -Items $items -DesiredPorts $desiredPorts -Declaration $decl -PkgPath $PkgPath
        $declLines.Clear()
        break
      }

      $declLines.Add($line)
      if ($line -match ';\s*$') {
        $decl = (($declLines | ForEach-Object { $_.Trim() }) -join ' ') -replace '\s+', ' '
        Add-PortItem -Items $items -DesiredPorts $desiredPorts -Declaration $decl -PkgPath $PkgPath
        $declLines.Clear()
      }
      continue
    }

    if ($skipDepth -gt 0) {
      if ($line -match '^\s*%\s*(if|for)\b') {
        $skipDepth++
      }
      elseif ($line -match '^\s*%\s*(endif|endfor)\b') {
        $skipDepth--
      }
      continue
    }

    if ($line -match '^\s*%\s*if\s+include_target_io\b') {
      $items.Add([pscustomobject]@{ Kind = 'Text'; Text = '      -----------------------------------' })
      $items.Add([pscustomobject]@{ Kind = 'Text'; Text = '      -- TARGET IO AND CLIP PORTS NOT USED' })
      $items.Add([pscustomobject]@{ Kind = 'Text'; Text = '      -----------------------------------' })
      $skipDepth = 1
      $hasIncludeTargetIo = $true
      continue
    }

    if ($line -match '^\s*%\s*(if|for)\b') {
      $skipDepth = 1
      continue
    }

    if ($line -match '^\s*%\s*(endif|endfor)\b') {
      continue
    }

    if ($line -match '\$\{') {
      continue
    }

    if ($line -match '^\s*\)\s*;\s*$') {
      break
    }

    if ($line -match '^\s*$' -or $line -match '^\s*--') {
      $items.Add([pscustomobject]@{
        Kind = 'Text'
        Text = $line
      })
      continue
    }

    $declLines.Add($line)
    if ($line -match ';\s*$') {
      $decl = (($declLines | ForEach-Object { $_.Trim() }) -join ' ') -replace '\s+', ' '
      Add-PortItem -Items $items -DesiredPorts $desiredPorts -Declaration $decl -PkgPath $PkgPath
      $declLines.Clear()
    }
  }

  return [pscustomobject]@{
    Items = $items
    DesiredPorts = $desiredPorts
    HasIncludeTargetIo = $hasIncludeTargetIo
  }
}

function Get-TopMapInfo {
  param([string]$TopPath)

  $lines = Get-Content -Path $TopPath
  $instanceIndex = -1
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match 'TheLvWindowWrapper:\s*TheLvWindowFlatWrapper') {
      $instanceIndex = $i
      break
    }
  }

  if ($instanceIndex -lt 0) {
    throw "Unable to find TheLvWindowWrapper instance in $TopPath"
  }

  $portMapIndex = -1
  for ($i = $instanceIndex; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s*port\s+map\s*\(\s*$') {
      $portMapIndex = $i
      break
    }
  }

  if ($portMapIndex -lt 0) {
    throw "Unable to find port map start in $TopPath"
  }

  $bodyStart = $portMapIndex + 1
  $bodyEnd = -1
  for ($i = $bodyStart; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '\);\s*(--.*)?\s*$') {
      $bodyEnd = $i
      break
    }
  }

  if ($bodyEnd -lt 0) {
    throw "Unable to find port map end in $TopPath"
  }

  return [pscustomobject]@{
    Lines = $lines
    BodyStart = $bodyStart
    BodyEnd = $bodyEnd
  }
}

function Get-ExistingMappings {
  param(
    [string[]]$BodyLines,
    [string]$TopPath
  )

  $map = @{}
  foreach ($line in $BodyLines) {
    if ($line -notmatch '^\s*(?<port>\w+)\s*=>') {
      continue
    }

    $portName = $Matches['port']
    $commentIndex = $line.IndexOf('--')
    if ($commentIndex -ge 0) {
      $beforeComment = $line.Substring(0, $commentIndex)
      $comment = $line.Substring($commentIndex)
    }
    else {
      $beforeComment = $line
      $comment = ''
    }

    $trimmedBeforeComment = $beforeComment.TrimEnd()
    if ($trimmedBeforeComment.EndsWith(');')) {
      $delimiterLength = 2
    }
    elseif ($trimmedBeforeComment.EndsWith(',')) {
      $delimiterLength = 1
    }
    else {
      $delimiterLength = 0
    }

    if ($delimiterLength -gt 0) {
      $codePart = $trimmedBeforeComment.Substring(0, $trimmedBeforeComment.Length - $delimiterLength)
      $spacesBeforeComment = $beforeComment.Substring($codePart.Length + $delimiterLength)
    }
    else {
      $codePart = $trimmedBeforeComment
      $spacesBeforeComment = $beforeComment.Substring($codePart.Length)
    }

    if ($map.ContainsKey($portName)) {
      throw "Duplicate mapping for port $portName in $TopPath"
    }

    $map[$portName] = [pscustomobject]@{
      CodePart = $codePart
      SpacesBeforeComment = $spacesBeforeComment
      Comment = $comment
    }
  }

  return $map
}

function New-MappingRecord {
  param(
    [string]$PortName,
    [string]$PortComment,
    [string]$Indent,
    [int]$NameWidth
  )

  $paddedName = $PortName.PadRight($NameWidth)
  return [pscustomobject]@{
    CodePart = "$Indent$paddedName => $PortName"
    SpacesBeforeComment = '  '
    Comment = $PortComment
  }
}

function Format-MappingLine {
  param(
    [pscustomobject]$Mapping,
    [bool]$IsLast
  )

  $line = $Mapping.CodePart
  if (-not $IsLast) {
    $line += ','
  }

  if ($Mapping.Comment) {
    $line += $Mapping.SpacesBeforeComment
    $line += $Mapping.Comment
  }

  return $line
}

function Rewrite-TopPortMap {
  param(
    [string]$TopPath,
    [pscustomobject]$PackageInfo
  )

  $topInfo = Get-TopMapInfo -TopPath $TopPath
  $bodyLines = $topInfo.Lines[$topInfo.BodyStart..$topInfo.BodyEnd]
  $existingMappings = Get-ExistingMappings -BodyLines $bodyLines -TopPath $TopPath

  $desiredPortItems = @($PackageInfo.Items | Where-Object { $_.Kind -eq 'Port' })
  $nameWidth = 0
  foreach ($item in $desiredPortItems) {
    if ($item.Name.Length -gt $nameWidth) {
      $nameWidth = $item.Name.Length
    }
  }

  $generatedItems = New-Object System.Collections.Generic.List[object]
  foreach ($item in $PackageInfo.Items) {
    if ($item.Kind -eq 'Text') {
      $generatedItems.Add([pscustomobject]@{
        Kind = 'Text'
        Text = $item.Text
      })
      continue
    }

    if ($existingMappings.ContainsKey($item.Name)) {
      $existing = $existingMappings[$item.Name]
      $spacesBeforeComment = $existing.SpacesBeforeComment
      if ($spacesBeforeComment -eq '') {
        $spacesBeforeComment = '  '
      }

      $mapping = [pscustomobject]@{
        CodePart = $existing.CodePart
        SpacesBeforeComment = $spacesBeforeComment
        Comment = $item.Comment
      }
    }
    else {
      $mapping = New-MappingRecord -PortName $item.Name -PortComment $item.Comment -Indent '      ' -NameWidth $nameWidth
    }

    $generatedItems.Add([pscustomobject]@{
      Kind = 'Port'
      Mapping = $mapping
    })
  }

  $portEntries = @($generatedItems | Where-Object { $_.Kind -eq 'Port' })
  $newBody = New-Object System.Collections.Generic.List[string]
  $portIndex = 0
  foreach ($entry in $generatedItems) {
    if ($entry.Kind -eq 'Text') {
      $newBody.Add([string]$entry.Text)
      continue
    }

    $isLast = ($portIndex -eq $portEntries.Count - 1)
    $newBody.Add((Format-MappingLine -Mapping $entry.Mapping -IsLast $isLast))
    $portIndex++
  }

  $newLines = New-Object System.Collections.Generic.List[string]
  if ($topInfo.BodyStart -gt 0) {
    foreach ($line in $topInfo.Lines[0..($topInfo.BodyStart - 1)]) {
      $newLines.Add([string]$line)
    }
  }
  foreach ($line in $newBody) {
    $newLines.Add([string]$line)
  }
  $newLines.Add('    );')
  if ($topInfo.BodyEnd + 1 -le $topInfo.Lines.Count - 1) {
    foreach ($line in $topInfo.Lines[($topInfo.BodyEnd + 1)..($topInfo.Lines.Count - 1)]) {
      $newLines.Add([string]$line)
    }
  }

  $text = [string]::Join("`r`n", $newLines) + "`r`n"
  [System.IO.File]::WriteAllText($TopPath, $text, [System.Text.Encoding]::ASCII)
}

function Get-TopPortNames {
  param([string]$TopPath)

  $topInfo = Get-TopMapInfo -TopPath $TopPath
  $names = New-Object System.Collections.Generic.List[string]
  for ($i = $topInfo.BodyStart; $i -le $topInfo.BodyEnd; $i++) {
    $line = $topInfo.Lines[$i]
    if ($line -match '^\s*(?<port>\w+)\s*=>') {
      $names.Add($Matches['port'])
    }
  }

  return [string[]]$names.ToArray()
}

function Get-PlaceholderPresent {
  param([string]$TopPath)

  $topInfo = Get-TopMapInfo -TopPath $TopPath
  for ($i = $topInfo.BodyStart; $i -le $topInfo.BodyEnd; $i++) {
    if ($topInfo.Lines[$i] -match '^\s*-- TARGET IO AND CLIP PORTS NOT USED\s*$') {
      return $true
    }
  }

  return $false
}

function Compare-PortLists {
  param(
    [string[]]$Expected,
    [string[]]$Actual
  )

  $missing = @($Expected | Where-Object { $_ -notin $Actual })
  $extra = @($Actual | Where-Object { $_ -notin $Expected })
  $orderMatch = ($Expected.Count -eq $Actual.Count)
  if ($orderMatch) {
    for ($i = 0; $i -lt $Expected.Count; $i++) {
      if ($Expected[$i] -ne $Actual[$i]) {
        $orderMatch = $false
        break
      }
    }
  }
  else {
    $orderMatch = $false
  }

  return [pscustomobject]@{
    Missing = $missing
    Extra = $extra
    OrderMatch = $orderMatch
  }
}

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$topFiles = @(Get-TopFiles -Root $root)

if ($topFiles.Count -eq 0) {
  throw 'No target top files found.'
}

if (-not $ValidateOnly) {
  foreach ($topFile in $topFiles) {
    $pkgPath = Join-Path $topFile.Directory.FullName 'PkgTheLvWindowFlatWrapper.vhd.mako'
    $packageInfo = Get-PackageInfo -PkgPath $pkgPath
    Rewrite-TopPortMap -TopPath $topFile.FullName -PackageInfo $packageInfo
  }
}

$failed = $false
foreach ($topFile in $topFiles) {
  $pkgPath = Join-Path $topFile.Directory.FullName 'PkgTheLvWindowFlatWrapper.vhd.mako'
  $packageInfo = Get-PackageInfo -PkgPath $pkgPath
  $expected = [string[]]$packageInfo.DesiredPorts.ToArray()
  $actual = Get-TopPortNames -TopPath $topFile.FullName
  $comparison = Compare-PortLists -Expected $expected -Actual $actual
  $placeholderPresent = Get-PlaceholderPresent -TopPath $topFile.FullName
  $placeholderOk = ((-not $packageInfo.HasIncludeTargetIo) -or $placeholderPresent)
  $status = ($comparison.Missing.Count -eq 0 -and $comparison.Extra.Count -eq 0 -and $comparison.OrderMatch -and $placeholderOk)

  $statusLine = '{0} | status={1} | expected={2} | actual={3} | missing={4} | extra={5} | order_match={6} | placeholder={7}' -f $topFile.FullName, $status, $expected.Count, $actual.Count, $comparison.Missing.Count, $comparison.Extra.Count, $comparison.OrderMatch, $placeholderPresent
  Write-Output $statusLine

  if (-not $status) {
    if ($comparison.Missing.Count -gt 0) {
      Write-Output ('  missing: ' + ($comparison.Missing -join ', '))
    }
    if ($comparison.Extra.Count -gt 0) {
      Write-Output ('  extra: ' + ($comparison.Extra -join ', '))
    }
    if (-not $placeholderOk) {
      Write-Output '  placeholder block missing'
    }
    $failed = $true
  }
}

if ($failed) {
  throw 'Validation failed for one or more top files.'
}