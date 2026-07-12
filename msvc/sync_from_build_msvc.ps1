[CmdletBinding()]
param(
  [string]$SourceRoot = (Split-Path -Parent $PSScriptRoot),
  [string]$GeneratedBuildRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) "build-msvc"),
  [string]$DestinationRoot = (Join-Path $PSScriptRoot "gemma")
)

$ErrorActionPreference = "Stop"

$SourceRoot = [System.IO.Path]::GetFullPath($SourceRoot).TrimEnd("\")
$GeneratedBuildRoot = [System.IO.Path]::GetFullPath($GeneratedBuildRoot).TrimEnd("\")
$DestinationRoot = [System.IO.Path]::GetFullPath($DestinationRoot).TrimEnd("\")

$projects = @(
  [pscustomobject]@{ Name = "hwy"; Generated = "_deps\highway-build\hwy.vcxproj" },
  [pscustomobject]@{ Name = "hwy_contrib"; Generated = "_deps\highway-build\hwy_contrib.vcxproj" },
  [pscustomobject]@{ Name = "libgemma"; Generated = "libgemma.vcxproj" },
  [pscustomobject]@{ Name = "gemma"; Generated = "gemma.vcxproj" },
  [pscustomobject]@{ Name = "gemma_api_client"; Generated = "gemma_api_client.vcxproj" },
  [pscustomobject]@{ Name = "gemma_api_server"; Generated = "gemma_api_server.vcxproj" },
  [pscustomobject]@{ Name = "benchmarks"; Generated = "benchmarks.vcxproj" },
  [pscustomobject]@{ Name = "single_benchmark"; Generated = "single_benchmark.vcxproj" },
  [pscustomobject]@{ Name = "debug_prompt"; Generated = "debug_prompt.vcxproj" },
  [pscustomobject]@{ Name = "migrate_weights"; Generated = "migrate_weights.vcxproj" }
)

function Save-XmlFile {
  param([xml]$Document, [string]$Path)

  $settings = New-Object System.Xml.XmlWriterSettings
  $settings.Indent = $true
  $settings.IndentChars = "  "
  $settings.NewLineChars = "`r`n"
  $settings.NewLineHandling = [System.Xml.NewLineHandling]::Replace
  $settings.Encoding = New-Object System.Text.UTF8Encoding($false)
  $writer = [System.Xml.XmlWriter]::Create($Path, $settings)
  try {
    $Document.Save($writer)
  } finally {
    $writer.Dispose()
  }
}

function Replace-PathRoots {
  param([xml]$Document)

  $allNodes = $Document.SelectNodes("//*")
  foreach ($node in $allNodes) {
    foreach ($attribute in @($node.Attributes)) {
      $value = $attribute.Value
      $value = $value.Replace($GeneratedBuildRoot + "\", '$(GeneratedBuildRoot)')
      $value = $value.Replace($SourceRoot + "\", '$(RepoRoot)')
      $attribute.Value = $value
    }

    foreach ($child in @($node.ChildNodes)) {
      if ($child.NodeType -ne [System.Xml.XmlNodeType]::Text) {
        continue
      }
      $value = $child.Value
      $value = $value.Replace($GeneratedBuildRoot + "\", '$(GeneratedBuildRoot)')
      $value = $value.Replace($SourceRoot + "\", '$(RepoRoot)')
      $child.Value = $value
    }
  }
}

function Convert-Project {
  param([pscustomobject]$Project)

  $sourcePath = Join-Path $GeneratedBuildRoot $Project.Generated
  if (-not (Test-Path -LiteralPath $sourcePath)) {
    throw "Generated project not found: $sourcePath"
  }

  [xml]$document = Get-Content -LiteralPath $sourcePath
  $namespace = New-Object System.Xml.XmlNamespaceManager($document.NameTable)
  $namespace.AddNamespace("m", "http://schemas.microsoft.com/developer/msbuild/2003")

  foreach ($node in @($document.SelectNodes("//m:CustomBuild", $namespace))) {
    [void]$node.ParentNode.RemoveChild($node)
  }

  foreach ($reference in @($document.SelectNodes("//m:ProjectReference[@Include]", $namespace))) {
    $referenceName = [System.IO.Path]::GetFileNameWithoutExtension($reference.Include)
    if ($referenceName -eq "ZERO_CHECK") {
      [void]$reference.ParentNode.RemoveChild($reference)
      continue
    }

    $knownProject = $projects | Where-Object { $_.Name -eq $referenceName } | Select-Object -First 1
    if ($null -eq $knownProject) {
      throw "Unsupported project reference '$referenceName' in $sourcePath"
    }
    $reference.Include = "..\$referenceName\$referenceName.vcxproj"
  }

  foreach ($node in @($document.SelectNodes("//m:OutDir", $namespace))) {
    $node.InnerText = '$(SolutionDir)build\$(Platform)\$(Configuration)\'
  }
  foreach ($node in @($document.SelectNodes("//m:IntDir", $namespace))) {
    $node.InnerText = '$(SolutionDir)build\obj\$(ProjectName)\$(Platform)\$(Configuration)\'
  }

  foreach ($node in @($document.SelectNodes("//m:AdditionalDependencies", $namespace))) {
    $value = $node.InnerText
    $value = $value -replace '(?:Debug|Release|MinSizeRel|RelWithDebInfo)\\libgemma\.lib', '$(OutDir)libgemma.lib'
    $value = $value -replace '_deps\\highway-build\\(?:Debug|Release|MinSizeRel|RelWithDebInfo)\\hwy_contrib\.lib', '$(OutDir)hwy_contrib.lib'
    $value = $value -replace '_deps\\highway-build\\(?:Debug|Release|MinSizeRel|RelWithDebInfo)\\hwy\.lib', '$(OutDir)hwy.lib'
    $node.InnerText = $value
  }

  Replace-PathRoots $document

  $projectDirectory = Join-Path $DestinationRoot $Project.Name
  New-Item -ItemType Directory -Path $projectDirectory -Force | Out-Null
  Save-XmlFile $document (Join-Path $projectDirectory ($Project.Name + ".vcxproj"))

  $filtersPath = $sourcePath + ".filters"
  if (Test-Path -LiteralPath $filtersPath) {
    [xml]$filters = Get-Content -LiteralPath $filtersPath
    Replace-PathRoots $filters
    Save-XmlFile $filters (Join-Path $projectDirectory ($Project.Name + ".vcxproj.filters"))
  }
}

if (-not (Test-Path -LiteralPath (Join-Path $GeneratedBuildRoot "CMakeCache.txt"))) {
  throw "Configure build-msvc before synchronizing the native solution."
}

New-Item -ItemType Directory -Path $DestinationRoot -Force | Out-Null
foreach ($project in $projects) {
  $projectDirectory = Join-Path $DestinationRoot $project.Name
  if (Test-Path -LiteralPath $projectDirectory) {
    Get-ChildItem -LiteralPath $projectDirectory -Force | ForEach-Object {
      Remove-Item -LiteralPath $_.FullName -Recurse -Force
    }
  }
  Convert-Project $project
}

$props = @'
<?xml version="1.0" encoding="utf-8"?>
<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <PropertyGroup>
    <RepoRoot>$([System.IO.Path]::GetFullPath('$(MSBuildThisFileDirectory)..\..\'))\</RepoRoot>
    <GeneratedBuildRoot>$(RepoRoot)build-msvc\</GeneratedBuildRoot>
  </PropertyGroup>
</Project>
'@
[System.IO.File]::WriteAllText(
  (Join-Path $DestinationRoot "Directory.Build.props"),
  $props.TrimStart() + "`r`n",
  (New-Object System.Text.UTF8Encoding($false)))

$solutionLines = New-Object System.Collections.Generic.List[string]
$solutionLines.Add("<Solution>")
$solutionLines.Add("  <Configurations>")
foreach ($configuration in @("Debug", "Release", "MinSizeRel", "RelWithDebInfo")) {
  $solutionLines.Add("    <BuildType Name=`"$configuration`" />")
}
$solutionLines.Add("    <Platform Name=`"x64`" />")
$solutionLines.Add("  </Configurations>")
foreach ($project in $projects) {
  $startup = if ($project.Name -eq "gemma") { ' DefaultStartup="true"' } else { "" }
  $solutionLines.Add("  <Project Path=`"$($project.Name)/$($project.Name).vcxproj`"$startup />")
}
$solutionLines.Add("</Solution>")
[System.IO.File]::WriteAllLines(
  (Join-Path $DestinationRoot "gemma.slnx"),
  $solutionLines,
  (New-Object System.Text.UTF8Encoding($false)))

Write-Host "Synchronized $($projects.Count) native MSVC projects to $DestinationRoot"
