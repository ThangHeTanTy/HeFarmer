# Tao (hoac dung lai) khoa ky APK cho ban phat hanh tren GitHub, roi huong
# dan dan vao GitHub Secrets. Giong TAO_KHOA_KY cua HeDeck.
#
# Android chi cho cai ban moi de len ban cu khi ca hai ky bang CUNG mot khoa.
# Mat khoa nay = moi nguoi dung phai go app cai lai. Vi vay:
#   - Khoa nam ngoai kho ma: %USERPROFILE%\HeFarmer-khoa-ky
#   - Chay lai script nay KHONG tao khoa moi, chi chep lai secret.
#   - Sao luu ca thu muc do (USB, Google Drive...).
#
# Thu tu chon khoa:
#   1. Khoa da cat o %USERPROFILE%\HeFarmer-khoa-ky (lan chay truoc)
#   2. Khoa cu theo BAO-MAT.md (android\key.properties) - dien thoai dang cai
#      APK ky bang khoa nay se cai de duoc ban GitHub, khong phai go app
#   3. Khoa debug cua may nay (neu dien thoai cai app bang flutter run)
#   4. Tao khoa moi

$ErrorActionPreference = "Stop"
$repo = "ThangHeTanTy/HeFarmer"
$root = Split-Path $PSScriptRoot -Parent
$dir  = Join-Path $env:USERPROFILE "HeFarmer-khoa-ky"
$jks  = Join-Path $dir "hefarmer-release.jks"
$passFile = Join-Path $dir "MAT_KHAU.txt"
$keyPassFile = Join-Path $dir "MAT_KHAU_KHOA.txt"
$aliasFile = Join-Path $dir "ALIAS.txt"
$debugKs = Join-Path $env:USERPROFILE ".android\debug.keystore"
$keyProps = Join-Path $root "android\key.properties"

function Fail($msg) {
    Write-Host "[X] $msg" -ForegroundColor Red
    exit 1
}

function Find-Keytool {
    $list = @()
    $cmd = Get-Command keytool -ErrorAction SilentlyContinue
    if ($cmd) { $list += $cmd.Source }
    if ($env:JAVA_HOME) { $list += Join-Path $env:JAVA_HOME "bin\keytool.exe" }
    $list += @(
        "$env:ProgramFiles\Android\Android Studio\jbr\bin\keytool.exe",
        "$env:ProgramFiles\Android\Android Studio\jre\bin\keytool.exe",
        "$env:LOCALAPPDATA\Programs\Android Studio\jbr\bin\keytool.exe"
    )
    return $list | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
}

# Doc file key.properties (dang key=value, Java cho phep "\\" trong duong dan)
function Read-Props($path) {
    $p = @{}
    Get-Content $path -Encoding UTF8 | ForEach-Object {
        $line = $_.Trim()
        if (-not $line -or $line.StartsWith("#")) { return }
        $i = $line.IndexOf("=")
        if ($i -lt 1) { return }
        $p[$line.Substring(0, $i).Trim()] = $line.Substring($i + 1).Trim().Replace("\\", "\")
    }
    return $p
}

function Save-Key($pass, $keyPass, $alias) {
    [System.IO.File]::WriteAllText($passFile, $pass)
    [System.IO.File]::WriteAllText($aliasFile, $alias)
    if ($keyPass -ne $pass) { [System.IO.File]::WriteAllText($keyPassFile, $keyPass) }
}

Write-Host ""
Write-Host "Khoa ky APK cho HeFarmer"
Write-Host ("-" * 58)

if (Test-Path $jks) {
    # ----- 1. Da co khoa -----
    Write-Host "  = Da co khoa, KHONG tao lai:" -ForegroundColor DarkGray
    Write-Host "      $jks" -ForegroundColor DarkGray
    if (-not (Test-Path $passFile)) { Fail "Thieu $passFile - khong biet mat khau cua khoa." }
    $pass = (Get-Content $passFile -Raw).Trim()
    $keyPass = if (Test-Path $keyPassFile) { (Get-Content $keyPassFile -Raw).Trim() } else { $pass }
    $alias = if (Test-Path $aliasFile) { (Get-Content $aliasFile -Raw).Trim() } else { "hefarmer" }
} else {
    New-Item -ItemType Directory -Force $dir | Out-Null
    $done = $false

    # ----- 2. Khoa cu theo BAO-MAT.md -----
    if (Test-Path $keyProps) {
        $p = Read-Props $keyProps
        # build.gradle.kts doc storeFile tuong doi theo thu muc android\app
        $old = $p["storeFile"]
        if ($old -and -not [System.IO.Path]::IsPathRooted($old)) {
            $old = Join-Path (Join-Path $root "android\app") $old
        }
        if ($old -and (Test-Path $old)) {
            Write-Host ""
            Write-Host "Tim thay khoa ky cu (theo BAO-MAT.md):" -ForegroundColor Cyan
            Write-Host "    $old"
            Write-Host "Dien thoai dang cai APK ky bang khoa nay se cai DE duoc ban"
            Write-Host "tu GitHub, khong phai go app, khong mat du lieu."
            $ans = Read-Host "Dung khoa nay cho ban phat hanh? (c/k, Enter = c)"
            if (-not $ans -or $ans -in @("c", "C", "y", "Y")) {
                Copy-Item $old $jks
                $pass = $p["storePassword"]
                $keyPass = if ($p["keyPassword"]) { $p["keyPassword"] } else { $pass }
                $alias = if ($p["keyAlias"]) { $p["keyAlias"] } else { "hefarmer" }
                if (-not $pass) { Fail "key.properties thieu storePassword." }
                Save-Key $pass $keyPass $alias
                Write-Host "  + Da chep khoa cu vao: $jks" -ForegroundColor Green
                $done = $true
            }
        } elseif ($old) {
            Write-Host "  ! key.properties tro toi $old nhung khong thay file." -ForegroundColor Yellow
        }
    }

    if (-not $done) {
        $keytool = Find-Keytool
        if (-not $keytool) {
            Fail "Khong tim thay keytool (di kem Java / Android Studio). Cai Android Studio hoac JDK 17 roi chay lai."
        }

        # ----- 3. Dung lai khoa debug -----
        # Dien thoai dang cai ban build tu chinh may nay (flutter run) thi ky
        # bang khoa debug cua may. Dung lai lam khoa phat hanh: lan dau chuyen
        # sang ban GitHub cai de duoc luon. Mat khau "android" ai cung biet,
        # nhung khong co file khoa thi vo dung - giu file nhu giu khoa moi.
        $reuse = $false
        if (Test-Path $debugKs) {
            Write-Host ""
            Write-Host "May nay co khoa debug cua Android Studio:" -ForegroundColor Cyan
            Write-Host "    $debugKs"
            Write-Host "Dien thoai dang cai HeFarmer build tu CHINH MAY NAY (flutter run,"
            Write-Host "Android Studio)? Dung lai khoa nay thi lan dau cai ban tu GitHub"
            Write-Host "KHONG phai go app. Neu app tren dien thoai build o may khac,"
            Write-Host "hoac chua ai cai, thi chon k de tao khoa moi."
            $ans = Read-Host "Dung lai khoa debug cua may nay? (c/k)"
            $reuse = $ans -in @("c", "C", "y", "Y")
        }

        if ($reuse) {
            $ErrorActionPreference = "Continue"
            & $keytool -list -keystore $debugKs -storepass android -alias androiddebugkey 2>&1 | Out-Null
            $ErrorActionPreference = "Stop"
            if ($LASTEXITCODE -ne 0) { Fail "Khong doc duoc khoa debug (mat khau khac 'android'?). Chay lai va chon k." }
            Copy-Item $debugKs $jks
            $pass = "android"; $keyPass = "android"; $alias = "androiddebugkey"
            Save-Key $pass $keyPass $alias
            Write-Host "  + Da chep khoa debug lam khoa phat hanh: $jks" -ForegroundColor Green
        } else {
            # ----- 4. Khoa moi -----
            # Mat khau ngau nhien 24 ky tu, bo cac chu de nham (0/O, 1/l/I).
            $chars = [char[]]"ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789"
            $bytes = New-Object byte[] 24
            [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
            $pass = -join ($bytes | ForEach-Object { $chars[$_ % $chars.Length] })
            & $keytool -genkeypair -keystore $jks -storetype PKCS12 -alias hefarmer `
                -keyalg RSA -keysize 4096 -validity 36500 `
                -storepass $pass -keypass $pass -dname "CN=HeFarmer, O=He IT, C=VN"
            if ($LASTEXITCODE -ne 0 -or -not (Test-Path $jks)) { Fail "keytool that bai" }
            $keyPass = $pass; $alias = "hefarmer"
            Save-Key $pass $keyPass $alias
            Write-Host "  + Da tao khoa moi: $jks" -ForegroundColor Green
        }
    }
}

# Build tren may (flutter build apk --release) cung ky bang khoa nay, de APK
# tu build va APK tai tu GitHub cai de len nhau duoc.
if (-not (Test-Path $keyProps)) {
    $props = @(
        "storePassword=$pass",
        "keyPassword=$keyPass",
        "keyAlias=$alias",
        "storeFile=$($jks.Replace('\', '/'))"
    ) -join "`n"
    [System.IO.File]::WriteAllText($keyProps, $props + "`n")
    Write-Host "  + Da ghi android\key.properties (khong len Git)" -ForegroundColor Green
}

$b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($jks))

Write-Host ""
Write-Host "SAO LUU NGAY thu muc nay (USB, Google Drive...):" -ForegroundColor Yellow
Write-Host "    $dir" -ForegroundColor Yellow
Write-Host "Mat khoa = moi nguoi dung phai go app cai lai." -ForegroundColor Yellow
Write-Host "Khong gui khoa hay mat khau cho ai, khong dua vao kho ma." -ForegroundColor Yellow
Write-Host ""
Write-Host "Dan cac secret vao GitHub. Trinh duyet se mo trang tao secret."
Write-Host ("-" * 58)

$url = "https://github.com/$repo/settings/secrets/actions/new"
$secrets = @(
    @("ANDROID_KEYSTORE_BASE64", $b64, "(da chep san, bam Ctrl+V)"),
    @("ANDROID_KEYSTORE_PASSWORD", $pass, "(da chep san, bam Ctrl+V)"),
    @("ANDROID_KEY_ALIAS", $alias, "$alias  (da chep san, bam Ctrl+V)")
)
if ($keyPass -ne $pass) {
    $secrets += ,@("ANDROID_KEY_PASSWORD", $keyPass, "(da chep san, bam Ctrl+V)")
}
$n = 0
foreach ($s in $secrets) {
    $n++
    Set-Clipboard -Value $s[1]
    Write-Host ""
    Write-Host "Secret $n/$($secrets.Count):  Name = $($s[0])" -ForegroundColor Cyan
    Write-Host "              Secret = $($s[2])"
    Start-Process $url
    Read-Host "Bam 'Add secret' tren GitHub xong thi nhan Enter o day"
}

Set-Clipboard -Value " "
Write-Host ""
Write-Host "[OK] Xong. Tu gio PHAT_HANH.bat se cho ra APK ky bang khoa nay." -ForegroundColor Green
Start-Process explorer $dir
