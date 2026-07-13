# Git Benchmark Script

This repository contains a PowerShell benchmark script that measures the runtime of common Git operations. It is designed to help compare Git performance before and after endpoint security or antivirus policy changes.

## Files

- `git-benchmark.ps1`: Benchmark runner.

## Requirements

- Windows PowerShell 5.1+ or PowerShell 7+
- Git for Windows available on `PATH`
- A local Git repository to test

## Usage

Run the script from this folder or provide a full path to it:

Minimal example (benchmark current directory):

```powershell
.\git-benchmark.ps1 -RepoPath .
```

```powershell
.\git-benchmark.ps1 `
	-RepoPath "C:\repos\large-repo" `
	-Iterations 5 `
	-OutputCsv ".\git-benchmark-results.csv"
```

### Parameters

- `-RepoPath` (required): Path to the target Git repository.
- `-Iterations` (optional, default `3`): Number of runs per benchmarked command.
- `-OutputCsv` (optional, default `.\git-benchmark-results.csv`): Output CSV path.
- `-Warmup` (optional switch): Performs a small warmup (`git status`, `git rev-parse HEAD`, `git diff`) before timing.
- `-VerboseOutput` (optional switch): Prints iteration progress messages.

Example with optional switches:

```powershell
.\git-benchmark.ps1 -RepoPath "C:\repos\large-repo" -Iterations 5 -Warmup -VerboseOutput
```

## What Is Benchmarked

The script times these commands for each iteration:

- `git status --untracked-files=all`
- `git diff`
- `git diff --cached`
- `git log --oneline -n 200`
- `git branch`
- `git rev-parse HEAD`
- `git ls-files`
- `git grep "TODO"`
- `git clean -fdn` (dry run)
- `git fsck --no-progress`

## Output

1. Console timing line per iteration and command.
2. Summary table with `AvgMs`, `MinMs`, and `MaxMs` by command.
3. CSV export with detailed rows.

### CSV Columns

- `Timestamp`
- `CommandName`
- `Iteration`
- `DurationMs`
- `ExitCode`
- `RepoPath`
- `GitVersion`
- `ComputerName`
- `Username`

## Typical Performance Optimisation Workflow

1. Run benchmark with current configuration.
2. Apply changes to configuration.
3. Run benchmark again with the same repo and iteration count.
4. Compare the two CSV outputs to identify improvements and regressions.