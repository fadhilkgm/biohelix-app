param(
    [Parameter(Mandatory)][string]$Bundle,
    [Parameter(Mandatory)][string]$Bundletool,
    [Parameter(Mandatory)][int]$VersionCode,
    [Parameter(Mandatory)][string]$VersionName,
    [int]$MinimumTargetSdk = 36,
    [string]$ReferenceBundle,
    [string]$Report
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$taskBundle = (Resolve-Path -LiteralPath $Bundle).Path
$taskBundletool = (Resolve-Path -LiteralPath $Bundletool).Path

function Invoke-ReleaseJava([string[]]$JavaArguments) {
    $taskJavaOutput = & java @JavaArguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Java validation failed: $taskJavaOutput"
    }
    return ($taskJavaOutput -join "`n")
}

function Get-SignerFingerprint([string]$Path) {
    $taskCert = & keytool -printcert -jarfile $Path 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Cannot inspect bundle signer: $Path" }
    $taskMatch = [regex]::Match(($taskCert -join "`n"), 'SHA256:\s*([A-Fa-f0-9:]+)')
    if (!$taskMatch.Success) { throw 'Bundle signer SHA-256 is missing.' }
    return $taskMatch.Groups[1].Value
}

$taskValidation = Invoke-ReleaseJava @('-jar', $taskBundletool, 'validate', "--bundle=$taskBundle")
$taskManifestText = Invoke-ReleaseJava @('-jar', $taskBundletool, 'dump', 'manifest', "--bundle=$taskBundle", '--module=base')
[xml]$taskManifest = $taskManifestText
$taskAndroidNs = 'http://schemas.android.com/apk/res/android'
$taskRoot = $taskManifest.manifest
if ($taskRoot.GetAttribute('package') -ne 'com.biohelix.app') { throw 'Unexpected package name.' }
if ([int]$taskRoot.GetAttribute('versionCode', $taskAndroidNs) -ne $VersionCode) { throw 'Incorrect version code.' }
if ($taskRoot.GetAttribute('versionName', $taskAndroidNs) -ne $VersionName) { throw 'Incorrect version name.' }
if ([int]$taskRoot.'uses-sdk'.GetAttribute('targetSdkVersion', $taskAndroidNs) -lt $MinimumTargetSdk) { throw 'Target SDK is below the release requirement.' }
if ($taskRoot.application.GetAttribute('usesCleartextTraffic', $taskAndroidNs) -ne 'false') { throw 'Cleartext traffic is enabled.' }
if ($taskRoot.application.GetAttribute('debuggable', $taskAndroidNs) -eq 'true') { throw 'Bundle is debuggable.' }
$taskPermissions = @($taskRoot.SelectNodes("*[starts-with(local-name(), 'uses-permission')]") | ForEach-Object { $_.GetAttribute('name', $taskAndroidNs) })
$taskHealthPermissions = @($taskPermissions | Where-Object { $_ -like 'android.permission.health.*' })
if ($taskHealthPermissions.Count -ne 0) {
    throw "Unexpected Health Connect permissions: $taskHealthPermissions"
}
if ($taskPermissions -contains 'android.permission.ACTIVITY_RECOGNITION' -or $taskPermissions -contains 'android.permission.BODY_SENSORS') {
    throw 'Activity/sensor access must not replace the removed Health Connect access.'
}
if ($taskManifestText -match 'healthdata|HealthPermissionsRationaleActivity|VIEW_PERMISSION_USAGE|HEALTH_PERMISSIONS|SHOW_PERMISSIONS_RATIONALE') {
    throw 'Health Connect entry points remain in the release manifest.'
}
$taskConfig = Invoke-ReleaseJava @('-jar', $taskBundletool, 'dump', 'config', "--bundle=$taskBundle")
if ($taskConfig -notmatch 'PAGE_ALIGNMENT_16K') { throw 'Bundle does not request 16 KB ZIP alignment.' }
$taskSignature = & jarsigner -verify $taskBundle 2>&1
if ($LASTEXITCODE -ne 0 -or ($taskSignature -join "`n") -notmatch 'jar verified') { throw 'Bundle signature verification failed.' }
$taskSigner = Get-SignerFingerprint $taskBundle
if ($ReferenceBundle) {
    $taskReference = (Resolve-Path -LiteralPath $ReferenceBundle).Path
    if ((Get-SignerFingerprint $taskReference) -ne $taskSigner) { throw 'Upload signer changed from the reference release.' }
}

$taskLibraries = @()
$taskZip = [System.IO.Compression.ZipFile]::OpenRead($taskBundle)
try {
    foreach ($taskDexEntry in $taskZip.Entries | Where-Object { $_.FullName -match '^base/dex/.+\.dex$' }) {
        $taskDexStream = $taskDexEntry.Open()
        $taskDexMemory = [System.IO.MemoryStream]::new()
        try {
            $taskDexStream.CopyTo($taskDexMemory)
            $taskDexText = [System.Text.Encoding]::Latin1.GetString($taskDexMemory.ToArray())
            if ($taskDexText.Contains('Landroidx/health/connect/') -or $taskDexText.Contains('HealthPermissionsRationaleActivity')) {
                throw "Health Connect native code remains in $($taskDexEntry.FullName)."
            }
        } finally {
            $taskDexStream.Dispose()
            $taskDexMemory.Dispose()
        }
    }
    foreach ($taskEntry in $taskZip.Entries | Where-Object { $_.FullName -match '^base/lib/(arm64-v8a|x86_64)/.+\.so$' }) {
        $taskStream = $taskEntry.Open()
        $taskMemory = [System.IO.MemoryStream]::new()
        try {
            $taskStream.CopyTo($taskMemory)
            $taskBytes = $taskMemory.ToArray()
        } finally {
            $taskStream.Dispose()
            $taskMemory.Dispose()
        }
        if ($taskBytes[0] -ne 127 -or $taskBytes[1] -ne 69 -or $taskBytes[2] -ne 76 -or $taskBytes[3] -ne 70 -or $taskBytes[4] -ne 2 -or $taskBytes[5] -ne 1) {
            throw "Unexpected ELF format: $($taskEntry.FullName)"
        }
        $taskHeaderOffset = [BitConverter]::ToUInt64($taskBytes, 32)
        $taskHeaderSize = [BitConverter]::ToUInt16($taskBytes, 54)
        $taskHeaderCount = [BitConverter]::ToUInt16($taskBytes, 56)
        $taskAlignments = @()
        $taskRelroEnds = @()
        $taskLoadSegments = @()
        $taskRelroSegments = @()
        for ($taskIndex = 0; $taskIndex -lt $taskHeaderCount; $taskIndex++) {
            $taskOffset = [int]($taskHeaderOffset + $taskIndex * $taskHeaderSize)
            $taskType = [BitConverter]::ToUInt32($taskBytes, $taskOffset)
            $taskFileOffset = [BitConverter]::ToUInt64($taskBytes, $taskOffset + 8)
            $taskAddress = [BitConverter]::ToUInt64($taskBytes, $taskOffset + 16)
            $taskMemorySize = [BitConverter]::ToUInt64($taskBytes, $taskOffset + 40)
            $taskAlignment = [BitConverter]::ToUInt64($taskBytes, $taskOffset + 48)
            if ($taskType -eq 1) {
                $taskAlignments += $taskAlignment
                $taskLoadSegments += [pscustomobject]@{ start = $taskAddress; end = $taskAddress + $taskMemorySize }
                if ($taskAlignment -lt 16384 -or ($taskFileOffset % 16384) -ne ($taskAddress % 16384)) {
                    throw "ELF LOAD segment is not 16 KB aligned: $($taskEntry.FullName)"
                }
            }
            if ($taskType -eq 0x6474e552) {
                $taskRelroEnd = $taskAddress + $taskMemorySize
                $taskRelroEnds += $taskRelroEnd
                $taskRelroSegments += [pscustomobject]@{ start = $taskAddress; end = $taskRelroEnd }
            }
        }
        foreach ($taskRelro in $taskRelroSegments) {
            # Android also permits an unaligned RELRO end that covers the
            # remainder of its LOAD segment. There is then no writable tail
            # on that page for mprotect to accidentally make read-only.
            $taskContainingLoads = @($taskLoadSegments | Where-Object { $_.start -le $taskRelro.start -and $_.end -gt $taskRelro.start })
            if ($taskContainingLoads.Count -ne 1) { throw "Cannot identify RELRO's LOAD segment: $($taskEntry.FullName)" }
            if ($taskRelro.end % 16384 -ne 0 -and $taskRelro.end -lt $taskContainingLoads[0].end) {
                throw "ELF RELRO has an unaligned end before writable data: $($taskEntry.FullName)"
            }
        }
        if ($taskAlignments.Count -eq 0) { throw "ELF has no LOAD segment: $($taskEntry.FullName)" }
        $taskLibraries += [pscustomobject]@{ path = $taskEntry.FullName; loadAlignments = $taskAlignments; relroEnds = $taskRelroEnds }
    }
} finally {
    $taskZip.Dispose()
}
if ($taskLibraries.Count -eq 0) { throw 'No 64-bit native libraries were verified.' }
$taskResult = [pscustomobject]@{
    bundle = $taskBundle
    bytes = (Get-Item -LiteralPath $taskBundle).Length
    sha256 = (Get-FileHash -LiteralPath $taskBundle -Algorithm SHA256).Hash
    package = $taskRoot.GetAttribute('package')
    versionCode = $VersionCode
    versionName = $VersionName
    minSdk = $taskRoot.'uses-sdk'.GetAttribute('minSdkVersion', $taskAndroidNs)
    targetSdk = $taskRoot.'uses-sdk'.GetAttribute('targetSdkVersion', $taskAndroidNs)
    permissions = $taskPermissions
    healthConnectPermissions = $taskHealthPermissions
    healthConnectSdkPresent = $false
    healthConnectEntryPointsPresent = $false
    uploadSignerSha256 = $taskSigner
    signatureVerified = $true
    bundletoolValidated = $true
    zipAlignment = 'PAGE_ALIGNMENT_16K'
    nativeLibraries = $taskLibraries
    runtimeTested = $false
    playConsoleAcceptanceVerified = $false
}
if ($Report) { $taskResult | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Report -Encoding utf8 }
$taskResult | Select-Object bundle, bytes, sha256, package, versionCode, versionName, minSdk, targetSdk, uploadSignerSha256, zipAlignment
Write-Output "Verified $($taskLibraries.Count) 64-bit native libraries."
