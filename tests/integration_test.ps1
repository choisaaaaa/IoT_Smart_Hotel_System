# IoT Smart Hotel Integration Test Script v4 - Using curl.exe
$ErrorActionPreference = "Continue"
$BASE = "http://localhost:9000/api/v1"

$SYS_ADMIN_TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6NSwidXNlcm5hbWUiOiJzeXNfYWRtaW4xIiwicGhvbmUiOiIxMzkwMDAwMDAwMSIsInJvbGUiOiJzeXN0ZW1fYWRtaW4iLCJob3RlbF9pZCI6MCwicGVybWlzc2lvbnMiOltdLCJpYXQiOjE3NzY5NzAxNTIsImV4cCI6MTc3NzA1NjU1MiwiYXVkIjoiaW90LWhvdGVsLXVzZXJzIiwiaXNzIjoiaW90LWhvdGVsLXN5c3RlbSJ9.OwRGIamkya_TSuCIiFagRFi90HT9MRgxxEnoSfIZV5k"
$HOTEL_ADMIN_TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6MjAsInVzZXJuYW1lIjoiYWRtaW4xIiwicGhvbmUiOiIxMzkwMDAwMDAwMiIsInJvbGUiOiJob3RlbF9hZG1pbiIsImhvdGVsX2lkIjoxLCJwZXJtaXNzaW9ucyI6W10sImlhdCI6MTc3Njk3MDE1MywiZXhwIjoxNzc3MDU2NTUzLCJhdWQiOiJpb3QtaG90ZWwtdXNlcnMiLCJpc3MiOiJpb3QtaG90ZWwtc3lzdGVtIn0.YBlaLB4CSNbHRRQUnDBRmst3rF29kxDeKvfs8ZcfH3I"
$STAFF_TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6OCwidXNlcm5hbWUiOiJyZWNlcHRpb25fMDEiLCJwaG9uZSI6IjEzOTAwMDAwMDA0Iiwicm9sZSI6InN0YWZmIiwiaG90ZWxfaWQiOjEsInBlcm1pc3Npb25zIjpbXSwiaWF0IjoxNzc2OTcwMTUzLCJleHAiOjE3NzcwNTY1NTMsImF1ZCI6ImlvdC1ob3RlbC11c2VycyIsImlzcyI6ImlvdC1ob3RlbC1zeXN0ZW0ifQ.CcMSBkLl7CAGwbNBd3i-qxml-wIc4NePwQc3D9k329Y"
$CUSTOMER_TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6NywidXNlcm5hbWUiOiJ5emoiLCJwaG9uZSI6IjEzOTAwMDAwMDA2Iiwicm9sZSI6ImN1c3RvbWVyIiwiaG90ZWxfaWQiOjAsInBlcm1pc3Npb25zIjpbXSwiaWF0IjoxNzc2OTcwMTUzLCJleHAiOjE3NzcwNTY1NTMsImF1ZCI6ImlvdC1ob3RlbC11c2VycyIsImlzcyI6ImlvdC1ob3RlbC1zeXN0ZW0ifQ.Yt8cKrr84Z2QYEtBOmKtUZdKhQTfUG6BTiblqL7r300"

$script:testResults = [System.Collections.ArrayList]::new()
$script:lastBody = $null
$script:lastCode = $null

function Test-Curl {
    param([string]$TestName, [string]$Method, [string]$Url, [string]$Token = "", [string]$Body = "", [string]$ExpectedStatus = "200")
    $script:lastBody = $null
    $script:lastCode = $null
    $curlArgs = @("-s", "-w", "`nHTTP_CODE:%{http_code}")
    if ($Method -ne "GET") { $curlArgs += "-X", $Method }
    if ($Token -ne "") { $curlArgs += "-H", "Authorization: Bearer $Token" }
    if ($Body -ne "") { 
        $curlArgs += "-H", "Content-Type: application/json"
        # Write body to temp file to avoid encoding issues
        $tmpFile = [System.IO.Path]::GetTempFileName()
        [System.IO.File]::WriteAllText($tmpFile, $Body, [System.Text.UTF8Encoding]::new($false))
        $curlArgs += "-d", "@$tmpFile"
    }
    $curlArgs += $Url
    
    try {
        $output = & curl.exe @curlArgs 2>&1
        $lines = $output -join "`n"
        # Split body and status code
        $codeMatch = [regex]::Match($lines, 'HTTP_CODE:(\d+)')
        if ($codeMatch.Success) {
            $script:lastCode = $codeMatch.Groups[1].Value
            $script:lastBody = $lines.Substring(0, $codeMatch.Index).Trim()
        } else {
            $script:lastCode = "0"
            $script:lastBody = $lines
        }
    } catch {
        $script:lastCode = "ERROR"
        $script:lastBody = $_.Exception.Message
    } finally {
        if ($Body -ne "" -and $tmpFile -and (Test-Path $tmpFile)) { Remove-Item $tmpFile -Force }
    }
    
    $pass = ($script:lastCode -eq $ExpectedStatus)
    $result = if ($pass) { "PASS" } else { "FAIL" }
    $display = if ($script:lastBody.Length -gt 120) { $script:lastBody.Substring(0,120) + "..." } else { $script:lastBody }
    $script:testResults.Add([PSCustomObject]@{ TestName = $TestName; Status = $script:lastCode; Expected = $ExpectedStatus; Result = $result; Response = $display }) | Out-Null
    Write-Host "[$result] $TestName | HTTP $($script:lastCode)"
}

function Get-JsonField { param([string]$Json, [string]$Field); try { $obj = $Json | ConvertFrom-Json; $parts = $Field.Split("."); $val = $obj; foreach ($p in $parts) { $val = $val.$p }; return $val } catch { return $null } }

# ============================================================
# FLOW 1: Customer Booking -> Checkin -> Control -> Checkout -> Review
# ============================================================
Write-Host "`n============================================================"
Write-Host "FLOW 1: Customer Booking -> Checkin -> Control -> Checkout -> Review"
Write-Host "============================================================"

# Step 1: Customer creates booking
Write-Host "`n--- F1.1 Customer creates booking ---"
$bookingBody = '{"hotel_id":1,"room_type_id":31,"check_in_date":"2026-04-29","check_out_date":"2026-04-30","guest_name":"IntegrationTestGuest","guest_phone":"13900000006"}'
Test-Curl -TestName "F1.1 Customer creates booking" -Method "POST" -Url "$BASE/bookings" -Token $CUSTOMER_TOKEN -Body $bookingBody -ExpectedStatus "200"
$bookingId = Get-JsonField -Json $script:lastBody -Field "data.id"
Write-Host "  >> Booking ID: $bookingId"

# Step 2: Staff confirms booking
Write-Host "`n--- F1.2 Staff confirms booking ---"
if ($bookingId) { Test-Curl -TestName "F1.2 Staff confirms booking" -Method "PUT" -Url "$BASE/bookings/$bookingId/confirm" -Token $STAFF_TOKEN -ExpectedStatus "200" } else { Write-Host "[SKIP] F1.2" }

# Step 3: Staff checks in (room_id=1 is KING type)
Write-Host "`n--- F1.3 Staff checks in guest ---"
if ($bookingId) {
    $checkinBody = '{"room_id":1,"guest_name":"IntegrationTestGuest","guest_phone":"13900000006"}'
    Test-Curl -TestName "F1.3 Staff checks in guest" -Method "PUT" -Url "$BASE/bookings/$bookingId/checkin" -Token $STAFF_TOKEN -Body $checkinBody -ExpectedStatus "200"
} else { Write-Host "[SKIP] F1.3" }

# Step 4: Customer views my room
Write-Host "`n--- F1.4 Customer views my room ---"
Test-Curl -TestName "F1.4 Customer views my room" -Method "GET" -Url "$BASE/rooms/guest/my-room" -Token $CUSTOMER_TOKEN -ExpectedStatus "200"

# Step 5: Customer views room devices
Write-Host "`n--- F1.5 Customer views room devices ---"
Test-Curl -TestName "F1.5 Customer views room devices" -Method "GET" -Url "$BASE/rooms/guest/my-room/devices" -Token $CUSTOMER_TOKEN -ExpectedStatus "200"

# Step 6: Customer views my bookings
Write-Host "`n--- F1.6 Customer views my bookings ---"
Test-Curl -TestName "F1.6 Customer views my bookings" -Method "GET" -Url "$BASE/bookings/my" -Token $CUSTOMER_TOKEN -ExpectedStatus "200"

# Step 7: Staff checks out
Write-Host "`n--- F1.7 Staff checks out guest ---"
if ($bookingId) { Test-Curl -TestName "F1.7 Staff checks out guest" -Method "PUT" -Url "$BASE/bookings/$bookingId/checkout" -Token $STAFF_TOKEN -ExpectedStatus "200" } else { Write-Host "[SKIP] F1.7" }

# Step 8: Customer creates review
Write-Host "`n--- F1.8 Customer creates review ---"
$reviewBody = '{"hotel_id":1,"score":4.5,"content":"Integration test review"}'
Test-Curl -TestName "F1.8 Customer creates review" -Method "POST" -Url "$BASE/reviews" -Token $CUSTOMER_TOKEN -Body $reviewBody -ExpectedStatus "200"

# ============================================================
# FLOW 2: Device Register -> Audit -> Control -> Sensor Data
# ============================================================
Write-Host "`n============================================================"
Write-Host "FLOW 2: Device Register -> Audit -> Control -> Sensor Data"
Write-Host "============================================================"

Write-Host "`n--- F2.1 Device registration ---"
$deviceBody = '{"device_id":"TEST_INT_003","device_name":"IntegrationTestDevice3","device_type":"room","hotel_id":1}'
Test-Curl -TestName "F2.1 Device registration" -Method "POST" -Url "$BASE/devices/register" -Token $HOTEL_ADMIN_TOKEN -Body $deviceBody -ExpectedStatus "200"
$deviceId = Get-JsonField -Json $script:lastBody -Field "data.device_id"
$dbDeviceId = Get-JsonField -Json $script:lastBody -Field "data.id"
Write-Host "  >> Device ID: $deviceId, DB ID: $dbDeviceId"

# If no DB ID from registration, try to find it
if (-not $dbDeviceId) {
    Write-Host "  >> Trying to find device in list..."
    Test-Curl -TestName "F2.1b Get device list" -Method "GET" -Url "$BASE/devices?hotel_id=1&page=1&pageSize=5" -Token $HOTEL_ADMIN_TOKEN -ExpectedStatus "200"
    try {
        $devList = $script:lastBody | ConvertFrom-Json
        foreach ($d in $devList.data) {
            if ($d.device_id -like "TEST_INT*") {
                $dbDeviceId = $d.id
                $deviceId = $d.device_id
                Write-Host "  >> Found device: ID=$deviceId, DB=$dbDeviceId"
                break
            }
        }
    } catch {}
}

Write-Host "`n--- F2.2 Admin audits device ---"
if ($dbDeviceId) {
    $auditBody = '{"status":"approved","room_id":1}'
    Test-Curl -TestName "F2.2 Admin audits device" -Method "PUT" -Url "$BASE/devices/$dbDeviceId/audit" -Token $HOTEL_ADMIN_TOKEN -Body $auditBody -ExpectedStatus "200"
} else { Write-Host "[SKIP] F2.2" }

Write-Host "`n--- F2.3 Send device command ---"
if ($dbDeviceId) {
    $cmdBody = '{"command_type":"relay_on","command_value":"on"}'
    Test-Curl -TestName "F2.3 Send device command" -Method "POST" -Url "$BASE/devices/$dbDeviceId/command" -Token $HOTEL_ADMIN_TOKEN -Body $cmdBody -ExpectedStatus "200"
} else { Write-Host "[SKIP] F2.3" }

Write-Host "`n--- F2.4 View sensor data ---"
if ($dbDeviceId) { Test-Curl -TestName "F2.4 View sensor data" -Method "GET" -Url "$BASE/devices/$dbDeviceId/sensor-data" -Token $HOTEL_ADMIN_TOKEN -ExpectedStatus "200" } else { Write-Host "[SKIP] F2.4" }

Write-Host "`n--- F2.5 View command history ---"
if ($dbDeviceId) { Test-Curl -TestName "F2.5 View command history" -Method "GET" -Url "$BASE/devices/$dbDeviceId/commands" -Token $HOTEL_ADMIN_TOKEN -ExpectedStatus "200" } else { Write-Host "[SKIP] F2.5" }

# ============================================================
# FLOW 3: Member -> Checkin -> Coupon -> Discount
# ============================================================
Write-Host "`n============================================================"
Write-Host "FLOW 3: Member -> Checkin -> Coupon -> Discount"
Write-Host "============================================================"
Test-Curl -TestName "F3.1 View member info" -Method "GET" -Url "$BASE/members/me" -Token $CUSTOMER_TOKEN -ExpectedStatus "200"
Test-Curl -TestName "F3.2 Member check-in" -Method "POST" -Url "$BASE/members/checkin" -Token $CUSTOMER_TOKEN -ExpectedStatus "200"
Test-Curl -TestName "F3.3 View level discounts" -Method "GET" -Url "$BASE/members/discounts" -Token $CUSTOMER_TOKEN -ExpectedStatus "200"
Test-Curl -TestName "F3.4 View my coupons" -Method "GET" -Url "$BASE/coupons/me" -Token $CUSTOMER_TOKEN -ExpectedStatus "200"
Test-Curl -TestName "F3.5 View hotel coupons" -Method "GET" -Url "$BASE/coupons/hotels" -Token $CUSTOMER_TOKEN -ExpectedStatus "200"

# ============================================================
# FLOW 4: RFID Issue -> Access Log
# ============================================================
Write-Host "`n============================================================"
Write-Host "FLOW 4: RFID Issue -> Access Log"
Write-Host "============================================================"
$rfidBody = '{"card_uid":"TEST_CARD_003","booking_id":1,"hotel_id":1,"room_id":1,"card_type":"guest"}'
Test-Curl -TestName "F4.1 RFID issue card" -Method "POST" -Url "$BASE/rfid/issue" -Token $STAFF_TOKEN -Body $rfidBody -ExpectedStatus "200"
Test-Curl -TestName "F4.2 Query booking cards" -Method "GET" -Url "$BASE/rfid/booking/1" -Token $STAFF_TOKEN -ExpectedStatus "200"
Test-Curl -TestName "F4.3 Card list" -Method "GET" -Url "$BASE/rfid/list" -Token $STAFF_TOKEN -ExpectedStatus "200"
Test-Curl -TestName "F4.4 Access log stats" -Method "GET" -Url "$BASE/rfid-access/logs/stats" -Token $STAFF_TOKEN -ExpectedStatus "200"

# ============================================================
# PART 2: Device Control & MQTT Integration Tests
# ============================================================
Write-Host "`n============================================================"
Write-Host "PART 2: Device Control & MQTT Integration Tests"
Write-Host "============================================================"
Test-Curl -TestName "MQTT.1 MQTT status" -Method "GET" -Url "$BASE/mqtt/status" -Token $HOTEL_ADMIN_TOKEN -ExpectedStatus "200"
Test-Curl -TestName "MQTT.2 MQTT logs" -Method "GET" -Url "$BASE/mqtt/logs" -Token $HOTEL_ADMIN_TOKEN -ExpectedStatus "200"
$mqttSendBody = '{"topic":"hotel/test","payload":"hello from integration test"}'
Test-Curl -TestName "MQTT.3 MQTT send" -Method "POST" -Url "$BASE/mqtt/send" -Token $HOTEL_ADMIN_TOKEN -Body $mqttSendBody -ExpectedStatus "200"
$beepBody = '{"device_id":"ROO_AF22DA59AFA8"}'
Test-Curl -TestName "MQTT.4 Device beep test" -Method "POST" -Url "$BASE/devices/test-beep" -Token $HOTEL_ADMIN_TOKEN -Body $beepBody -ExpectedStatus "200"
Test-Curl -TestName "MQTT.5 Environment data" -Method "GET" -Url "$BASE/environment" -Token $HOTEL_ADMIN_TOKEN -ExpectedStatus "200"
Test-Curl -TestName "MQTT.6 Environment dashboard" -Method "GET" -Url "$BASE/environment/dashboard" -Token $HOTEL_ADMIN_TOKEN -ExpectedStatus "200"
Test-Curl -TestName "MQTT.7 Fire alarms" -Method "GET" -Url "$BASE/environment/fire-alarms" -Token $HOTEL_ADMIN_TOKEN -ExpectedStatus "200"
Test-Curl -TestName "MQTT.8 Device groups" -Method "GET" -Url "$BASE/device-groups" -Token $HOTEL_ADMIN_TOKEN -ExpectedStatus "200"
Test-Curl -TestName "MQTT.9 Device alarms" -Method "GET" -Url "$BASE/device-alarms" -Token $HOTEL_ADMIN_TOKEN -ExpectedStatus "200"
Test-Curl -TestName "MQTT.10 Device alarm stats" -Method "GET" -Url "$BASE/device-alarms/stats" -Token $HOTEL_ADMIN_TOKEN -ExpectedStatus "200"
Test-Curl -TestName "MQTT.11 IR remote brands" -Method "GET" -Url "$BASE/ir-remote/brands" -Token $HOTEL_ADMIN_TOKEN -ExpectedStatus "200"
Test-Curl -TestName "MQTT.12 Firmware updates" -Method "GET" -Url "$BASE/firmware/updates" -Token $HOTEL_ADMIN_TOKEN -ExpectedStatus "200"

# ============================================================
# PART 3: Concurrency Tests
# ============================================================
Write-Host "`n============================================================"
Write-Host "PART 3: Concurrency Tests"
Write-Host "============================================================"

# Create a booking for concurrency tests
Write-Host "`n--- Preparing booking for concurrency tests ---"
$concBody1 = '{"hotel_id":1,"room_type_id":31,"check_in_date":"2026-05-01","check_out_date":"2026-05-02","guest_name":"ConcTest1","guest_phone":"13900000006"}'
Test-Curl -TestName "CONC.PREP Create booking 1" -Method "POST" -Url "$BASE/bookings" -Token $CUSTOMER_TOKEN -Body $concBody1 -ExpectedStatus "200"
$concBookingId1 = Get-JsonField -Json $script:lastBody -Field "data.id"
Write-Host "  >> Concurrency Booking 1 ID: $concBookingId1"
if ($concBookingId1) { Test-Curl -TestName "CONC.PREP Confirm booking 1" -Method "PUT" -Url "$BASE/bookings/$concBookingId1/confirm" -Token $STAFF_TOKEN -ExpectedStatus "200" }

# Test 1: Concurrent checkin same room
Write-Host "`n--- CONC.1 Concurrent checkin same room ---"
if ($concBookingId1) {
    $checkinBodyConc = '{"room_id":1,"guest_name":"ConcTest1","guest_phone":"13900000006"}'
    $concScript = {
        param($baseUrl, $token, $url, $bodyFile, $delay)
        if ($delay -gt 0) { Start-Sleep -Milliseconds $delay }
        $result = & curl.exe -s -w "`nHTTP_CODE:%{http_code}" -X PUT -H "Authorization: Bearer $token" -H "Content-Type: application/json" -d "@$bodyFile" $url 2>&1
        $result -join ""
    }
    # Write body to temp file
    $tmpFile1 = [System.IO.Path]::GetTempFileName()
    [System.IO.File]::WriteAllText($tmpFile1, $checkinBodyConc, [System.Text.UTF8Encoding]::new($false))
    
    $job1 = Start-Job -ScriptBlock $concScript -ArgumentList $BASE, $STAFF_TOKEN, "$BASE/bookings/$concBookingId1/checkin", $tmpFile1, 0
    $job2 = Start-Job -ScriptBlock $concScript -ArgumentList $BASE, $STAFF_TOKEN, "$BASE/bookings/$concBookingId1/checkin", $tmpFile1, 100
    $res1 = Receive-Job $job1 -Wait -AutoRemoveJob
    $res2 = Receive-Job $job2 -Wait -AutoRemoveJob
    Remove-Item $tmpFile1 -Force -ErrorAction SilentlyContinue
    
    $d1 = if ($res1.Length -gt 200) { $res1.Substring(0,200) } else { $res1 }
    $d2 = if ($res2.Length -gt 200) { $res2.Substring(0,200) } else { $res2 }
    Write-Host "  R1: $d1"
    Write-Host "  R2: $d2"
    $anyOk = ($res1 -match "HTTP_CODE:200" -or $res2 -match "HTTP_CODE:200")
    $concResult1 = if ($anyOk) { "PASS" } else { "FAIL" }
    $script:testResults.Add([PSCustomObject]@{ TestName = "CONC.1 Concurrent checkin same room"; Status = "N/A"; Expected = "At least one 200"; Result = $concResult1; Response = "R1:$d1 | R2:$d2" }) | Out-Null
    Write-Host "[$concResult1] CONC.1 Concurrent checkin same room"
} else { Write-Host "[SKIP] CONC.1" }

# Test 2: Concurrent confirm same booking
Write-Host "`n--- CONC.2 Concurrent confirm same booking ---"
$concBody3 = '{"hotel_id":1,"room_type_id":31,"check_in_date":"2026-05-03","check_out_date":"2026-05-04","guest_name":"ConcTest3","guest_phone":"13900000006"}'
Test-Curl -TestName "CONC.PREP Create booking for concurrent confirm" -Method "POST" -Url "$BASE/bookings" -Token $CUSTOMER_TOKEN -Body $concBody3 -ExpectedStatus "200"
$concBookingId2 = Get-JsonField -Json $script:lastBody -Field "data.id"
Write-Host "  >> Concurrency Booking 2 ID: $concBookingId2"

if ($concBookingId2) {
    $confirmScript = {
        param($baseUrl, $token, $url, $delay)
        if ($delay -gt 0) { Start-Sleep -Milliseconds $delay }
        $result = & curl.exe -s -w "`nHTTP_CODE:%{http_code}" -X PUT -H "Authorization: Bearer $token" -H "Content-Type: application/json" $url 2>&1
        $result -join ""
    }
    $job3 = Start-Job -ScriptBlock $confirmScript -ArgumentList $BASE, $STAFF_TOKEN, "$BASE/bookings/$concBookingId2/confirm", 0
    $job4 = Start-Job -ScriptBlock $confirmScript -ArgumentList $BASE, $STAFF_TOKEN, "$BASE/bookings/$concBookingId2/confirm", 100
    $res3 = Receive-Job $job3 -Wait -AutoRemoveJob
    $res4 = Receive-Job $job4 -Wait -AutoRemoveJob
    $d3 = if ($res3.Length -gt 200) { $res3.Substring(0,200) } else { $res3 }
    $d4 = if ($res4.Length -gt 200) { $res4.Substring(0,200) } else { $res4 }
    Write-Host "  R1: $d3"
    Write-Host "  R2: $d4"
    $anyOk2 = ($res3 -match "HTTP_CODE:200" -or $res4 -match "HTTP_CODE:200")
    $concResult2 = if ($anyOk2) { "PASS" } else { "FAIL" }
    $script:testResults.Add([PSCustomObject]@{ TestName = "CONC.2 Concurrent confirm same booking"; Status = "N/A"; Expected = "At least one 200"; Result = $concResult2; Response = "R1:$d3 | R2:$d4" }) | Out-Null
    Write-Host "[$concResult2] CONC.2 Concurrent confirm same booking"
} else { Write-Host "[SKIP] CONC.2" }

# Test 3: Concurrent booking same room type same date
Write-Host "`n--- CONC.3 Concurrent booking same room type same date ---"
$concBodyA = '{"hotel_id":1,"room_type_id":31,"check_in_date":"2026-05-05","check_out_date":"2026-05-06","guest_name":"ConcTestA","guest_phone":"13900000008"}'
$concBodyB = '{"hotel_id":1,"room_type_id":31,"check_in_date":"2026-05-05","check_out_date":"2026-05-06","guest_name":"ConcTestB","guest_phone":"13900000009"}'
$bookingScript = {
    param($baseUrl, $token, $url, $bodyFile, $delay)
    if ($delay -gt 0) { Start-Sleep -Milliseconds $delay }
    $result = & curl.exe -s -w "`nHTTP_CODE:%{http_code}" -X POST -H "Authorization: Bearer $token" -H "Content-Type: application/json" -d "@$bodyFile" $url 2>&1
    $result -join ""
}
$tmpFileA = [System.IO.Path]::GetTempFileName()
[System.IO.File]::WriteAllText($tmpFileA, $concBodyA, [System.Text.UTF8Encoding]::new($false))
$tmpFileB = [System.IO.Path]::GetTempFileName()
[System.IO.File]::WriteAllText($tmpFileB, $concBodyB, [System.Text.UTF8Encoding]::new($false))

$job5 = Start-Job -ScriptBlock $bookingScript -ArgumentList $BASE, $CUSTOMER_TOKEN, "$BASE/bookings", $tmpFileA, 0
$job6 = Start-Job -ScriptBlock $bookingScript -ArgumentList $BASE, $CUSTOMER_TOKEN, "$BASE/bookings", $tmpFileB, 100
$res5 = Receive-Job $job5 -Wait -AutoRemoveJob
$res6 = Receive-Job $job6 -Wait -AutoRemoveJob
Remove-Item $tmpFileA, $tmpFileB -Force -ErrorAction SilentlyContinue
$d5 = if ($res5.Length -gt 200) { $res5.Substring(0,200) } else { $res5 }
$d6 = if ($res6.Length -gt 200) { $res6.Substring(0,200) } else { $res6 }
Write-Host "  R1: $d5"
Write-Host "  R2: $d6"
$anyOk3 = ($res5 -match "HTTP_CODE:200" -or $res6 -match "HTTP_CODE:200")
$concResult3 = if ($anyOk3) { "PASS" } else { "FAIL" }
$script:testResults.Add([PSCustomObject]@{ TestName = "CONC.3 Concurrent booking same room type same date"; Status = "N/A"; Expected = "At least one 200"; Result = $concResult3; Response = "R1:$d5 | R2:$d6" }) | Out-Null
Write-Host "[$concResult3] CONC.3 Concurrent booking same room type same date"

# Test 4: Concurrent room status update
Write-Host "`n--- CONC.4 Concurrent room status update ---"
$statusScript = {
    param($baseUrl, $token, $url, $bodyFile, $delay)
    if ($delay -gt 0) { Start-Sleep -Milliseconds $delay }
    $result = & curl.exe -s -w "`nHTTP_CODE:%{http_code}" -X PATCH -H "Authorization: Bearer $token" -H "Content-Type: application/json" -d "@$bodyFile" $url 2>&1
    $result -join ""
}
$tmpFile7 = [System.IO.Path]::GetTempFileName()
[System.IO.File]::WriteAllText($tmpFile7, '{"status":"maintenance"}', [System.Text.UTF8Encoding]::new($false))
$tmpFile8 = [System.IO.Path]::GetTempFileName()
[System.IO.File]::WriteAllText($tmpFile8, '{"status":"available"}', [System.Text.UTF8Encoding]::new($false))

$job7 = Start-Job -ScriptBlock $statusScript -ArgumentList $BASE, $HOTEL_ADMIN_TOKEN, "$BASE/rooms/1/status", $tmpFile7, 0
$job8 = Start-Job -ScriptBlock $statusScript -ArgumentList $BASE, $HOTEL_ADMIN_TOKEN, "$BASE/rooms/1/status", $tmpFile8, 100
$res7 = Receive-Job $job7 -Wait -AutoRemoveJob
$res8 = Receive-Job $job8 -Wait -AutoRemoveJob
Remove-Item $tmpFile7, $tmpFile8 -Force -ErrorAction SilentlyContinue
$d7 = if ($res7.Length -gt 200) { $res7.Substring(0,200) } else { $res7 }
$d8 = if ($res8.Length -gt 200) { $res8.Substring(0,200) } else { $res8 }
Write-Host "  R1: $d7"
Write-Host "  R2: $d8"
$anyOk4 = ($res7 -match "HTTP_CODE:200" -or $res8 -match "HTTP_CODE:200")
$concResult4 = if ($anyOk4) { "PASS" } else { "FAIL" }
$script:testResults.Add([PSCustomObject]@{ TestName = "CONC.4 Concurrent room status update"; Status = "N/A"; Expected = "At least one 200"; Result = $concResult4; Response = "R1:$d7 | R2:$d8" }) | Out-Null
Write-Host "[$concResult4] CONC.4 Concurrent room status update"

# Reset room status
Test-Curl -TestName "CLEANUP Reset room 1 status" -Method "PATCH" -Url "$BASE/rooms/1/status" -Token $HOTEL_ADMIN_TOKEN -Body '{"status":"available"}' -ExpectedStatus "200"

# ============================================================
# PART 4: Data Consistency Tests
# ============================================================
Write-Host "`n============================================================"
Write-Host "PART 4: Data Consistency Tests"
Write-Host "============================================================"

Write-Host "`n--- Preparing booking for data consistency tests ---"
$dcBody = '{"hotel_id":1,"room_type_id":31,"check_in_date":"2026-05-10","check_out_date":"2026-05-11","guest_name":"DataConsistencyTest","guest_phone":"13900000006"}'
Test-Curl -TestName "DC.PREP Create booking" -Method "POST" -Url "$BASE/bookings" -Token $CUSTOMER_TOKEN -Body $dcBody -ExpectedStatus "200"
$dcBookingId = Get-JsonField -Json $script:lastBody -Field "data.id"
Write-Host "  >> DC Booking ID: $dcBookingId"

if ($dcBookingId) {
    Test-Curl -TestName "DC.PREP Confirm booking" -Method "PUT" -Url "$BASE/bookings/$dcBookingId/confirm" -Token $STAFF_TOKEN -ExpectedStatus "200"
    # Checkin with room 5 (TWIN type)
    $dcCheckinBody = '{"room_id":5,"guest_name":"DataConsistencyTest","guest_phone":"13900000006"}'
    Test-Curl -TestName "DC.PREP Checkin" -Method "PUT" -Url "$BASE/bookings/$dcBookingId/checkin" -Token $STAFF_TOKEN -Body $dcCheckinBody -ExpectedStatus "200"
    
    # Test 1: After checkin, room status should be occupied
    Write-Host "`n--- DC.1 Room status after checkin ---"
    Test-Curl -TestName "DC.1 Room status after checkin" -Method "GET" -Url "$BASE/rooms/5" -Token $HOTEL_ADMIN_TOKEN -ExpectedStatus "200"
    $roomStatus = Get-JsonField -Json $script:lastBody -Field "data.room_status"
    $statusOk = ($roomStatus -eq "occupied")
    $dcResult1 = if ($statusOk) { "PASS" } else { "FAIL" }
    $script:testResults.Add([PSCustomObject]@{ TestName = "DC.1 Room status=occupied after checkin"; Status = $roomStatus; Expected = "occupied"; Result = $dcResult1; Response = "Actual: $roomStatus" }) | Out-Null
    Write-Host "[$dcResult1] DC.1 Room status=$roomStatus (expected: occupied)"
    
    # Test 2: After checkout, room status should be cleaning/available
    Write-Host "`n--- DC.2 Room status after checkout ---"
    Test-Curl -TestName "DC.2 Checkout" -Method "PUT" -Url "$BASE/bookings/$dcBookingId/checkout" -Token $STAFF_TOKEN -ExpectedStatus "200"
    Test-Curl -TestName "DC.2 Room status after checkout" -Method "GET" -Url "$BASE/rooms/5" -Token $HOTEL_ADMIN_TOKEN -ExpectedStatus "200"
    $roomStatus2 = Get-JsonField -Json $script:lastBody -Field "data.room_status"
    $statusOk2 = ($roomStatus2 -eq "cleaning" -or $roomStatus2 -eq "available")
    $dcResult2 = if ($statusOk2) { "PASS" } else { "FAIL" }
    $script:testResults.Add([PSCustomObject]@{ TestName = "DC.2 Room status=cleaning/available after checkout"; Status = $roomStatus2; Expected = "cleaning/available"; Result = $dcResult2; Response = "Actual: $roomStatus2" }) | Out-Null
    Write-Host "[$dcResult2] DC.2 Room status=$roomStatus2 (expected: cleaning/available)"
}

# Test 3: Cancel booking and check inventory
Write-Host "`n--- DC.3 Cancel booking and check inventory ---"
$dcBody2 = '{"hotel_id":1,"room_type_id":31,"check_in_date":"2026-05-15","check_out_date":"2026-05-16","guest_name":"DCCancelTest","guest_phone":"13900000006"}'
Test-Curl -TestName "DC.3 Create booking for cancel test" -Method "POST" -Url "$BASE/bookings" -Token $CUSTOMER_TOKEN -Body $dcBody2 -ExpectedStatus "200"
$dcBookingId2 = Get-JsonField -Json $script:lastBody -Field "data.id"
Write-Host "  >> DC Cancel Test Booking ID: $dcBookingId2"
if ($dcBookingId2) {
    Test-Curl -TestName "DC.3 Cancel booking" -Method "PUT" -Url "$BASE/bookings/$dcBookingId2/cancel" -Token $CUSTOMER_TOKEN -ExpectedStatus "200"
    Test-Curl -TestName "DC.3 Check availability after cancel" -Method "GET" -Url "$BASE/hotels/1/room-types?check_in_date=2026-05-15&check_out_date=2026-05-16" -Token $STAFF_TOKEN -ExpectedStatus "200"
}

# Test 4: RFID card after checkout
Write-Host "`n--- DC.4 RFID card after checkout ---"
Test-Curl -TestName "DC.4 RFID card after checkout" -Method "GET" -Url "$BASE/rfid/booking/1" -Token $STAFF_TOKEN -ExpectedStatus "200"

# ============================================================
# Summary
# ============================================================
Write-Host "`n============================================================"
Write-Host "TEST SUMMARY"
Write-Host "============================================================"
$passCount = ($script:testResults | Where-Object { $_.Result -eq "PASS" }).Count
$failCount = ($script:testResults | Where-Object { $_.Result -eq "FAIL" }).Count
$totalCount = $script:testResults.Count
Write-Host "Total: $totalCount | PASS: $passCount | FAIL: $failCount"
Write-Host ""
Write-Host ("{0,-4} {1,-50} {2,-6} {3,-6} {4}" -f "No.", "Test Name", "Result", "HTTP", "Key Response")
Write-Host ("-" * 110)
$i = 1
foreach ($r in $script:testResults) {
    $shortResp = if ($r.Response.Length -gt 50) { $r.Response.Substring(0,50) + "..." } else { $r.Response }
    Write-Host ("{0,-4} {1,-50} {2,-6} {3,-6} {4}" -f $i, $r.TestName, $r.Result, $r.Status, $shortResp)
    $i++
}
if ($totalCount -gt 0) { Write-Host "`nPASS RATE: $([math]::Round($passCount/$totalCount*100, 1))%" }
