param([string]$Path = ".", [switch]$OutputToPipeline, [switch]$ShowSummary, [Switch]$DirectoriesFirst,
[string]$Pattern = $null, [switch]$UseAsciiTree)

if ($OutputToPipeline.IsPresent -eq $false) { Clear-Host }

function Format-NumberAsOrderOfMagnitude() {
    param($Number, $Magnitude = 1024)
$power = 0;
    $MagnitudeTerms = @('B ','KB','MB','GB','TB','PB','EB')
    while (($power -lt $MagnitudeTerms.Count) -and ($power += 1)) {
        if ($Number -lt [Math]::Pow($Magnitude, $power)) {
            return "$(("{0:N2}", "{0}")[$power -eq 1] -f ($Number / [Math]::Pow($Magnitude, $power - 1))) $($MagnitudeTerms[$power - 1])"
        }
    }
    return "UNKNOWN";
}

function Out-ItemInfo() {
    param($Item, $Prefix = "")

    $mode = $Item.Mode;
    $lastWriteTime = $Item.LastWriteTime
    $length = $Item.Length
    $name = $Item.Name

    $formattedLineWriteTime = $lastWriteTime.ToString("yyyy-MM-dd HH:mm:ss");
    $formattedLength = Format-NumberAsOrderOfMagnitude -Number $length

    $color = "Red"
    if ($mode.StartsWith("d")) { $formattedLength = ""; $color = "Blue" }

    $isMatch = ($Pattern -ne "") -and ($name -match $Pattern);
    if ($Pattern -ne "") { $matchPrefix = @("     ", "M => ")[$isMatch -and $OutputToPipeline.IsPresent]; }

    if ($OutputToPipeline.IsPresent) { 
        Write-Output "$($matchPrefix)$Prefix [$mode $formattedLineWriteTime $($formattedLength.PadLeft(10, ' ')) $name]"
    } else {
        Write-Host "$Prefix " -NoNewline
        Write-Host "[$mode $formattedLineWriteTime $($formattedLength.PadLeft(10, ' ')) $name]" -ForegroundColor $color -BackgroundColor @("Black","White")[$isMatch]
    }
}

function Get-ChildItems() {
    param($path, $linePrefix = "")

    $summary = New-Object PSObject -Property @{ File = 0; Directory = 0; Size = 0 }

    $directories = @(Get-ChildItem -Path $path -Directory -Force -ErrorAction SilentlyContinue)
    $files = @(Get-ChildItem -Path $path -File -Force -ErrorAction SilentlyContinue)

    $allItems = @($files + $directories);
    if ($DirectoriesFirst.IsPresent) { $allItems = @($directories + $files); }

    for ($index = 0; $index -lt $allItems.Length; $index++) {
        $nowSuffix = $TreeParts[0];
        $nextSuffix = $TreeParts[1]

        if ($index -eq ($allItems.Length - 1) -and ($ShowSummary.IsPresent -eq $false)) {            
                $nowSuffix = $TreeParts[2];
                $nextSuffix = $TreeParts[3];
        }

        Out-ItemInfo -Item $allItems[$index] -Prefix ($linePrefix + $nowSuffix)
        if ($allItems[$index].Mode.StartsWith("d")) {
            $summary.Directory += 1;            
        } else {
            $summary.File += 1;            
            $summary.Size += $allItems[$index].Length;            
        }

        if ($allItems[$index].mode.StartsWith("d")) {
            Get-ChildItems -path $allItems[$index].FullName -linePrefix ($linePrefix + $nextSuffix)
            $childItemSummary = $Global:GetChildItemsReturn;
            $summary.File += $childItemSummary.File;
            $summary.Directory += $childItemSummary.Directory;
            $summary.Size += $childItemSummary.Size;
        }
    }
    if ($ShowSummary.IsPresent -eq $true) {
        if ($OutputToPipeline.IsPresent) { 
            $matchPrefix = ("","     ")[$Pattern -ne ""];
            Write-Output "$($matchPrefix)$($linePrefix + $TreeParts[2]) [Files:$($summary.File.ToString('N0')) Directories:$($summary.Directory.ToString('N0')) Size:$(Format-NumberAsOrderOfMagnitude -Number $summary.Size)]"
        } else {
            Write-Host "$($linePrefix + $TreeParts[2]) " -NoNewline
            Write-Host "[Files:$($summary.File.ToString('N0')) Directories:$($summary.Directory.ToString('N0')) Size:$(Format-NumberAsOrderOfMagnitude -Number $summary.Size)]" -ForegroundColor Yellow
        }
    }
    $Global:GetChildItemsReturn = $summary;
}

$TreeParts = @("├───","│    ","└───","     ");
if ($UseAsciiTree.IsPresent) { $TreeParts = @("+---","|    ","\---","     "); }

(Resolve-Path $path).Path
Get-ChildItems $Path
