$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$dataPath = Join-Path $root "data/universities.json"
$readmePath = Join-Path $root "README.md"
$beginMarker = "<!-- BEGIN:repo-table -->"
$endMarker = "<!-- END:repo-table -->"
$minStars = 10
$tableMinStars = 16
$minLastCommitAt = [DateTime]"2024-01-01T00:00:00Z"

$labelUndergraduate = ([char]0x672C).ToString() + ([char]0x79D1)
$labelMaster = ([char]0x7855).ToString() + ([char]0x58EB)
$labelDoctoral = ([char]0x535A).ToString() + ([char]0x58EB)
$headerSchool = ([char]0x5B66).ToString() + ([char]0x6821)
$headerRepo = ([char]0x4ED3).ToString() + ([char]0x5E93)
$headerDegreeTypes = ([char]0x5B66).ToString() + ([char]0x4F4D) + ([char]0x7C7B) + ([char]0x578B)
$headerLastCommit = ([char]0x6700).ToString() + ([char]0x8FD1) + ([char]0x63D0) + ([char]0x4EA4)

function Format-DegreeTypes {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$DegreeTypes
    )

    $labels = foreach ($degreeType in $DegreeTypes) {
        switch ($degreeType) {
            "undergraduate" { $labelUndergraduate }
            "master" { $labelMaster }
            "doctoral" { $labelDoctoral }
            default { $degreeType }
        }
    }

    ($labels | Select-Object -Unique) -join " / "
}

function Get-GitHubJson {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $json = gh api $Path --header "Accept: application/vnd.github+json" --header "X-GitHub-Api-Version: 2022-11-28"
    if (-not $json) {
        throw "Empty response from gh api for $Path"
    }
    $json | ConvertFrom-Json
}

$syncedAt = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
$data = Get-Content $dataPath -Raw -Encoding UTF8 | ConvertFrom-Json

$retainedSchools = @()

foreach ($school in $data) {
    $retainedTemplates = @()
    foreach ($template in $school.templates) {
        $repoInfo = Get-GitHubJson -Path "/repos/$($template.repo)"
        $commitInfo = Get-GitHubJson -Path "/repos/$($template.repo)/commits?per_page=1"
        $lastCommitAtUtc = ([DateTime]$commitInfo[0].commit.committer.date).ToUniversalTime()
        $lastCommitAt = $lastCommitAtUtc.ToString("yyyy-MM-ddTHH:mm:ssZ")
        $stars = [int]$repoInfo.stargazers_count
        $isArchived = [bool]$repoInfo.archived

        $template | Add-Member -NotePropertyName github_metrics -NotePropertyValue ([pscustomobject]@{
            stars = $stars
            last_commit_at = $lastCommitAt
            last_synced_at = $syncedAt
        }) -Force

        if (-not $isArchived -and $stars -ge $minStars -and $lastCommitAtUtc -ge $minLastCommitAt) {
            $retainedTemplates += [pscustomobject]@{
                repo = $template.repo
                degree_types = @($template.degree_types)
                github_metrics = [pscustomobject]@{
                    stars = $stars
                    last_commit_at = $lastCommitAt
                    last_synced_at = $syncedAt
                }
            }
        }
    }

    if ($retainedTemplates.Count -gt 0) {
        $retainedSchools += [pscustomobject]@{
            school_id = $school.school_id
            school_name_zh = $school.school_name_zh
            templates = @($retainedTemplates)
        }
    }
}

$retainedSchools | ConvertTo-Json -Depth 100 | Set-Content $dataPath -Encoding UTF8

$rows = foreach ($school in $retainedSchools) {
    foreach ($template in $school.templates) {
        if ([int]$template.github_metrics.stars -lt $tableMinStars) {
            continue
        }
        [pscustomobject]@{
            school_name_zh = $school.school_name_zh
            repo = $template.repo
            url = "https://github.com/$($template.repo)"
            degree_types = Format-DegreeTypes -DegreeTypes @($template.degree_types)
            stars = [int]$template.github_metrics.stars
            last_commit_date = ([string]$template.github_metrics.last_commit_at).Substring(0, 10)
        }
    }
}

$sortedRows = $rows | Sort-Object @{ Expression = "stars"; Descending = $true }, school_name_zh, repo

$tableLines = @(
    "| $headerSchool | $headerRepo | $headerDegreeTypes | Stars | $headerLastCommit |",
    "| --- | --- | --- | ---: | --- |"
)

foreach ($row in $sortedRows) {
    $repoLabel = $row.repo
    $tableLines += "| {0} | [`{1}`]({2}) | {3} | {4} | {5} |" -f $row.school_name_zh, $repoLabel, $row.url, $row.degree_types, $row.stars, $row.last_commit_date
}

$tableMarkdown = ($tableLines -join "`n")
$readme = Get-Content $readmePath -Raw -Encoding UTF8
$pattern = "(?s)$([regex]::Escape($beginMarker)).*?$([regex]::Escape($endMarker))"
$replacement = "$beginMarker`n$tableMarkdown`n$endMarker"
$updatedReadme = [regex]::Replace($readme, $pattern, $replacement)
$updatedReadme | Set-Content $readmePath -Encoding UTF8
