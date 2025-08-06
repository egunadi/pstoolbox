# Define repositories with corresponding branches
$repos = @(
    @{ Path = "c:\Users\egunadi\Git\mi-caretrack\"; Branch = "main" },
    @{ Path = "c:\Users\egunadi\Git\jupyter-notebooks\"; Branch = "prod" }
)

# Initialize an array to store commits
$allCommits = @()

foreach ($repo in $repos) {
    Write-Host "Collecting commits from $($repo.Path) [$($repo.Branch)]..."

    # Fetch commits from specified branch without changing directories
    $commits = git -C $repo.Path log $repo.Branch --pretty=format:"%h %ad %s" --date=short

    # Add commits to the combined array
    $allCommits += $commits
}

# Sort combined commits by date (newest first)
$sortedCommits = $allCommits | Sort-Object { ($_ -split " ")[1] } -Descending

# Save sorted commits to a single consolidated file
$sortedCommits | Set-Content -Path ".\commits.txt"

Write-Host "Commits successfully consolidated into commits.txt"
