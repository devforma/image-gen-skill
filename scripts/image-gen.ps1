[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [Alias("p")]
    [string]$Prompt,

    [Alias("s")]
    [string]$Size = "1k",

    [Alias("q")]
    [ValidateSet("high", "medium", "low")]
    [string]$Quality = "medium",

    [Alias("n")]
    [ValidateRange(1, 100)]
    [int]$Count = 1,

    [Alias("o")]
    [string]$Output = "image",

    [Alias("k")]
    [string]$ApiKey
)

$ErrorActionPreference = "Stop"
$ApiUrl = "https://cf.api.fan/v1/images/generations"
$Model = "gpt-image-2"

if (-not $ApiKey) {
    $ApiKey = $env:PACKY_IMAGE_API_KEY
}

if (-not $ApiKey) {
    throw "Set PACKY_IMAGE_API_KEY or pass -ApiKey."
}

$SizeMap = @{
    "1k" = "1536x1024"
    "2k" = "2048x1152"
    "4k" = "3840x2160"
}
$SizeKey = $Size.ToLowerInvariant()
if ($SizeMap.ContainsKey($SizeKey)) {
    $ResolvedSize = $SizeMap[$SizeKey]
}
elseif ($Size -match "^[1-9][0-9]*x[1-9][0-9]*$") {
    $ResolvedSize = $Size
}
else {
    throw "Size must be 1k, 2k, 4k, or WIDTHxHEIGHT."
}

$RequestBody = @{
    model = $Model
    prompt = $Prompt
    size = $ResolvedSize
    quality = $Quality
    output_format = "png"
    n = $Count
} | ConvertTo-Json -Compress

$Headers = @{
    Authorization = "Bearer $ApiKey"
}
$RequestParameters = @{
    Uri = $ApiUrl
    Method = "Post"
    Headers = $Headers
    ContentType = "application/json"
    Body = [Text.Encoding]::UTF8.GetBytes($RequestBody)
}
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

try {
    $Response = Invoke-RestMethod @RequestParameters
}
catch {
    throw "Image generation request failed: $($_.Exception.Message)"
}

$Images = @($Response.data)
if ($Images.Count -eq 0) {
    throw "The response did not contain image data."
}

$OutputPrefix = $Output -replace "(?i)\.png$", ""
$SavedCount = 0
for ($Index = 0; $Index -lt $Images.Count; $Index++) {
    $EncodedImage = $Images[$Index].b64_json
    if (-not $EncodedImage) {
        throw "Image $($Index + 1) did not contain b64_json data."
    }

    if ($Count -eq 1) {
        $OutputPath = "$OutputPrefix.png"
    }
    else {
        $OutputPath = "$OutputPrefix-$($Index + 1).png"
    }
    $OutputPath = [IO.Path]::GetFullPath($OutputPath)
    $OutputDirectory = [IO.Path]::GetDirectoryName($OutputPath)
    if ($OutputDirectory) {
        [IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
    }

    $TempPath = "$OutputPath.tmp"
    try {
        [IO.File]::WriteAllBytes(
            $TempPath,
            [Convert]::FromBase64String($EncodedImage)
        )
        Move-Item -LiteralPath $TempPath -Destination $OutputPath -Force
    }
    catch {
        Remove-Item -LiteralPath $TempPath -Force -ErrorAction SilentlyContinue
        throw "Could not save image $($Index + 1): $($_.Exception.Message)"
    }

    $SavedCount++
    Write-Output "Saved: $OutputPath"
}

if ($SavedCount -ne $Count) {
    throw "Expected $Count images but received $SavedCount."
}
