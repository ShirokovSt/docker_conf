# Служебный, вызывается из _net.bat: создаёт сеть Docker devstack_default с подсетью, свободной на этом ПК.
# Свободная - не пересекается ни с маршрутами Windows (VPN, WSL, другие подключённые сети), ни с другими сетями Docker:
# иначе контейнеры не достанут до серверов из этого диапазона.
# Подсеть выбирается один раз; если сеть уже есть, скрипт ничего не делает.

param([string]$Name = 'devstack_default')   # имя - параметром только для проверки скрипта

docker network inspect $Name *> $null
if ($LASTEXITCODE -eq 0) { exit 0 }

# CIDR -> [начало, конец] диапазона адресов числами
function Get-Range([string]$cidr) {
    $ip, $bits = $cidr.Split('/')
    $b = ([System.Net.IPAddress]::Parse($ip)).GetAddressBytes()
    $n = [double]$b[0] * 16777216 + [double]$b[1] * 65536 + [double]$b[2] * 256 + [double]$b[3]
    $size = [math]::Pow(2, 32 - [int]$bits)
    $start = [math]::Floor($n / $size) * $size
    return , @($start, ($start + $size - 1))
}

# занятые диапазоны: маршруты Windows (без маршрута по умолчанию, loopback, multicast, broadcast) и сети Docker
$busy = New-Object System.Collections.ArrayList
Get-NetRoute -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.DestinationPrefix -ne '0.0.0.0/0' -and $_.DestinationPrefix -notmatch '^(127|22[4-9]|23\d|24\d|25[0-5]|169\.254)\.' } |
    ForEach-Object { [void]$busy.Add((Get-Range $_.DestinationPrefix)) }
foreach ($id in (docker network ls -q)) {
    $subnets = docker network inspect $id --format '{{range .IPAM.Config}}{{.Subnet}} {{end}}'
    foreach ($s in ("$subnets" -split '\s+')) {
        if ($s -match '^\d+\.\d+\.\d+\.\d+/\d+$') { [void]$busy.Add((Get-Range $s)) }
    }
}

# кандидаты по порядку: 172.25.x (как раньше по умолчанию), 172.29.x, 172.22.x, 10.250.x, 192.168.200-255
$candidates = @()
foreach ($second in 25, 29, 22) { foreach ($third in 0..255) { $candidates += "172.$second.$third.0/24" } }
foreach ($third in 0..255) { $candidates += "10.250.$third.0/24" }
foreach ($third in 200..255) { $candidates += "192.168.$third.0/24" }

foreach ($c in $candidates) {
    $r = Get-Range $c
    $clash = $false
    foreach ($b in $busy) {
        if ($r[0] -le $b[1] -and $b[0] -le $r[1]) { $clash = $true; break }
    }
    if ($clash) { continue }
    docker network create --driver bridge --subnet $c $Name | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[!] Не удалось создать сеть $Name с подсетью $c - см. ошибку Docker выше."
        exit 1
    }
    Write-Host "Сеть $Name создана: подсеть $c - свободна на этом ПК."
    exit 0
}

Write-Host "[!] Не нашлось свободной подсети для сети ${Name}: все кандидаты пересекаются с маршрутами ПК или сетями Docker."
exit 1
