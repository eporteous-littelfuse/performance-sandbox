<#
Git + Antivirus Benchmark Script
Purpose:
- Benchmark common Git operations under current endpoint security conditions
- Produce repeatable timing data for IT/security investigation
- Compare performance before/after AV exclusions or policy changes

Tested on:
- PowerShell 5.1+
- Git for Windows

Usage:
  .\git-av-benchmark.ps1 `
      -RepoPath "C:\repos\large-repo" `
      -Iterations 5 `
      -OutputCsv ".\git-benchmark-results.csv"

Optional:
  -Warmup
  -VerboseOutput

Recommended:
- Run once with AV enabled
- Run again with repo/process/path exclusions applied
- Compare CSV outputs

#>

param(
    [Parameter(Mandatory=$true)]
    [string]$RepoPath,

    [int]$Iterations = 3,

    [string]$OutputCsv = ".\git-benchmark-results.csv",

    [switch]$Warmup,

    [switch]$VerboseOutput
)

# -----------------------------
# Validation
# -----------------------------

if (-not (Test-Path $RepoPath)) {
    throw "RepoPath does not exist: $RepoPath"
}

Push-Location $RepoPath

try {
    git rev-parse --git-dir *> $null
    if ($LASTEXITCODE -ne 0) {
        throw "Not a git repository: $RepoPath"
    }
}
catch {
    Pop-Location
    throw
}

# -----------------------------
# Helper Functions
# -----------------------------

function Invoke-Benchmark {
    param(
        [string]$Name,
        [scriptblock]$Script
    )

    $results = @()

    for ($i = 1; $i -le $Iterations; $i++) {

        if ($VerboseOutput) {
            Write-Host "Running [$Name] iteration $i/$Iterations"
        }

        $sw = [System.Diagnostics.Stopwatch]::StartNew()

        try {
            & $Script
            $exitCode = $LASTEXITCODE
        }
        catch {
            $exitCode = -1
        }

        $sw.Stop()

        $result = [PSCustomObject]@{
            Timestamp      = Get-Date
            CommandName    = $Name
            Iteration      = $i
            DurationMs     = [math]::Round($sw.Elapsed.TotalMilliseconds, 2)
            ExitCode       = $exitCode
            RepoPath       = $RepoPath
            GitVersion     = (git --version)
            ComputerName   = $env:COMPUTERNAME
            Username       = $env:USERNAME
        }

        $results += $result

        Write-Host ("{0,-25} Iteration {1} : {2,10} ms" -f $Name, $i, $result.DurationMs)
    }

    return $results
}

# -----------------------------
# Warmup
# -----------------------------

if ($Warmup) {
    Write-Host "Performing filesystem warmup..."

    git status *> $null
    git rev-parse HEAD *> $null
    git diff *> $null
}

# -----------------------------
# Benchmark Definitions
# -----------------------------

$allResults = @()

$benchmarks = @(
    @{
        Name = "git status"
        Script = {
            git status --untracked-files=all *> $null
        }
    },
    @{
        Name = "git diff"
        Script = {
            git diff *> $null
        }
    },
    @{
        Name = "git diff cached"
        Script = {
            git diff --cached *> $null
        }
    },
    @{
        Name = "git log"
        Script = {
            git log --oneline -n 200 *> $null
        }
    },
    @{
        Name = "git branch"
        Script = {
            git branch *> $null
        }
    },
    @{
        Name = "git rev-parse"
        Script = {
            git rev-parse HEAD *> $null
        }
    },
    @{
        Name = "git ls-files"
        Script = {
            git ls-files *> $null
        }
    },
    @{
        Name = "git grep"
        Script = {
            git grep "TODO" *> $null
        }
    },
    @{
        Name = "git clean dry-run"
        Script = {
            git clean -fdn *> $null
        }
    },
    @{
        Name = "git fsck"
        Script = {
            git fsck --no-progress *> $null
        }
    },
    @{
        Name = "git pull"
        Script = {
            git pull *> $null
        }
    }
)

# -----------------------------
# Execute Benchmarks
# -----------------------------

Write-Host ""
Write-Host "========================================="
Write-Host "Git AV Performance Benchmark"
Write-Host "Repository : $RepoPath"
Write-Host "Iterations : $Iterations"
Write-Host "========================================="
Write-Host ""

foreach ($benchmark in $benchmarks) {

    $results = Invoke-Benchmark `
        -Name $benchmark.Name `
        -Script $benchmark.Script

    $allResults += $results
}

# -----------------------------
# Summary
# -----------------------------

Write-Host ""
Write-Host "============= SUMMARY ==================="

$summary = $allResults |
    Group-Object CommandName |
    ForEach-Object {

        $durations = $_.Group.DurationMs

        [PSCustomObject]@{
            Command   = $_.Name
            AvgMs     = [math]::Round(($durations | Measure-Object -Average).Average, 2)
            MinMs     = [math]::Round(($durations | Measure-Object -Minimum).Minimum, 2)
            MaxMs     = [math]::Round(($durations | Measure-Object -Maximum).Maximum, 2)
        }
    } |
    Sort-Object AvgMs -Descending

$summary | Format-Table -AutoSize

# -----------------------------
# Export
# -----------------------------

$allResults |
    Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8

Write-Host ""
Write-Host "Detailed results exported to:"
Write-Host "  $OutputCsv"

# -----------------------------
# Environment Info
# -----------------------------

Write-Host ""
Write-Host "============= ENVIRONMENT ==============="

$gitVersion = git --version

Write-Host "Git Version : $gitVersion"
Write-Host "PowerShell  : $($PSVersionTable.PSVersion)"
Write-Host "OS          : $([System.Environment]::OSVersion.VersionString)"
Write-Host "CPU Cores   : $([Environment]::ProcessorCount)"

Pop-Location