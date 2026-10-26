# Служебный, вызывается из beszel-setup.bat: подключает агента Beszel к hub (один раз, потом ничего не делает).
# Hub Beszel сам создаёт ключ при первом запуске и показывает его только в интерфейсе, а агент без ключа не
# стартует. Поэтому: берём ключ у hub по API, кладём его в общий том (его читает агент, KEY_FILE),
# добавляем систему beszel-agent:45876 в hub и запускаем агента.

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$hub  = 'http://localhost:8091'
$mail = 'admin@example.com'   # как USER_EMAIL / USER_PASSWORD hub в teamcity/docker-compose.yml
$pass = 'admin123'

docker container inspect beszel *> $null
if ($LASTEXITCODE -ne 0) { Write-Host '[!] Контейнер beszel не создан - запустите TeamCity (teamcity\start.bat).'; exit 1 }

# ждём, пока hub отвечает
$auth = $null
for ($i = 0; $i -lt 30 -and -not $auth; $i++) {
    try {
        $auth = Invoke-RestMethod -Method Post -Uri "$hub/api/collections/users/auth-with-password" `
            -ContentType 'application/json' -Body (@{ identity = $mail; password = $pass } | ConvertTo-Json)
    } catch { Start-Sleep -Seconds 2 }
}
if (-not $auth) { Write-Host "[!] Beszel не отвечает на $hub или учётка $mail не подходит."; exit 1 }
$h = @{ Authorization = $auth.token }

# ключ hub -> том beszel-data (файл читает агент)
$key = (Invoke-RestMethod -Uri "$hub/api/beszel/getkey" -Headers $h).key
$tmp = Join-Path $env:TEMP 'beszel-id_ed25519.pub'
[System.IO.File]::WriteAllText($tmp, $key)
docker cp $tmp beszel:/beszel_data/id_ed25519.pub
Remove-Item $tmp -ErrorAction SilentlyContinue

# система в hub: агент в этой же сети Docker, имя контейнера = адрес
$filter = [uri]::EscapeDataString("host='beszel-agent'")
$have = Invoke-RestMethod -Uri "$hub/api/collections/systems/records?filter=($filter)" -Headers $h
if ($have.totalItems -eq 0) {
    $body = @{ name = 'Docker Desktop'; host = 'beszel-agent'; port = '45876'; users = @($auth.record.id) } | ConvertTo-Json
    [void](Invoke-RestMethod -Method Post -Uri "$hub/api/collections/systems/records" -Headers $h -ContentType 'application/json' -Body $body)
    Write-Host 'Beszel: система "Docker Desktop" добавлена.'
}

# агент без ключа завершался сразу - запускаем (если уже работает, ничего не делаем)
if ((docker container inspect -f '{{.State.Running}}' beszel-agent) -ne 'true') { docker start beszel-agent | Out-Null }
Write-Host "Beszel: $hub ($mail / $pass)"
