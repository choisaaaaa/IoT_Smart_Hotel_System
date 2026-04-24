# Debug script for POST /bookings 404
$BASE = "http://localhost:9000/api/v1"
$CUSTOMER_TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6NywidXNlcm5hbWUiOiJ5emoiLCJwaG9uZSI6IjEzOTAwMDAwMDA2Iiwicm9sZSI6ImN1c3RvbWVyIiwiaG90ZWxfaWQiOjAsInBlcm1pc3Npb25zIjpbXSwiaWF0IjoxNzc2OTcwMTUzLCJleHAiOjE3NzcwNTY1NTMsImF1ZCI6ImlvdC1ob3RlbC11c2VycyIsImlzcyI6ImlvdC1ob3RlbC1zeXN0ZW0ifQ.Yt8cKrr84Z2QYEtBOmKtUZdKhQTfUG6BTiblqL7r300"
$STAFF_TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6OCwidXNlcm5hbWUiOiJyZWNlcHRpb25fMDEiLCJwaG9uZSI6IjEzOTAwMDAwMDA0Iiwicm9sZSI6InN0YWZmIiwiaG90ZWxfaWQiOjEsInBlcm1pc3Npb25zIjpbXSwiaWF0IjoxNzc2OTcwMTUzLCJleHAiOjE3NzcwNTY1NTMsImF1ZCI6ImlvdC1ob3RlbC11c2VycyIsImlzcyI6ImlvdC1ob3RlbC1zeXN0ZW0ifQ.CcMSBkLl7CAGwbNBd3i-qxml-wIc4NePwQc3D9k329Y"
$HOTEL_ADMIN_TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6MjAsInVzZXJuYW1lIjoiYWRtaW4xIiwicGhvbmUiOiIxMzkwMDAwMDAwMiIsInJvbGUiOiJob3RlbF9hZG1pbiIsImhvdGVsX2lkIjoxLCJwZXJtaXNzaW9ucyI6W10sImlhdCI6MTc3Njk3MDE1MywiZXhwIjoxNzc3MDU2NTUzLCJhdWQiOiJpb3QtaG90ZWwtdXNlcnMiLCJpc3MiOiJpb3QtaG90ZWwtc3lzdGVtIn0.YBlaLB4CSNbHRRQUnDBRmst3rF29kxDeKvfs8ZcfH3I"

# Test 1: GET /bookings/my (should work)
Write-Host "=== Test 1: GET /bookings/my ==="
try {
    $r = Invoke-WebRequest -Uri "$BASE/bookings/my" -Method GET -Headers @{Authorization="Bearer $CUSTOMER_TOKEN"} -UseBasicParsing -TimeoutSec 10
    Write-Host "STATUS: $($r.StatusCode)"
    Write-Host "BODY: $($r.Content.Substring(0, [Math]::Min(300, $r.Content.Length)))"
} catch {
    Write-Host "ERROR: $($_.Exception.Message)"
}

# Test 2: GET /bookings (list)
Write-Host "`n=== Test 2: GET /bookings ==="
try {
    $r = Invoke-WebRequest -Uri "$BASE/bookings" -Method GET -Headers @{Authorization="Bearer $STAFF_TOKEN"} -UseBasicParsing -TimeoutSec 10
    Write-Host "STATUS: $($r.StatusCode)"
    Write-Host "BODY: $($r.Content.Substring(0, [Math]::Min(300, $r.Content.Length)))"
} catch {
    Write-Host "ERROR: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        $sr = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        Write-Host "BODY: $($sr.ReadToEnd())"
    }
}

# Test 3: POST /bookings/test (test endpoint)
Write-Host "`n=== Test 3: POST /bookings/test ==="
try {
    $r = Invoke-WebRequest -Uri "$BASE/bookings/test" -Method POST -Headers @{Authorization="Bearer $CUSTOMER_TOKEN"; "Content-Type"="application/json"} -UseBasicParsing -TimeoutSec 10
    Write-Host "STATUS: $($r.StatusCode)"
    Write-Host "BODY: $($r.Content)"
} catch {
    Write-Host "ERROR: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        $sr = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        Write-Host "BODY: $($sr.ReadToEnd())"
    }
}

# Test 4: POST /bookings with minimal body
Write-Host "`n=== Test 4: POST /bookings with minimal body ==="
$body = '{"hotel_id":1,"room_type_id":1,"check_in_date":"2026-04-29","check_out_date":"2026-04-30","guest_name":"Test","guest_phone":"13900000006"}'
try {
    $r = Invoke-WebRequest -Uri "$BASE/bookings" -Method POST -Headers @{Authorization="Bearer $CUSTOMER_TOKEN"; "Content-Type"="application/json"} -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -UseBasicParsing -TimeoutSec 15
    Write-Host "STATUS: $($r.StatusCode)"
    Write-Host "BODY: $($r.Content.Substring(0, [Math]::Min(500, $r.Content.Length)))"
} catch {
    Write-Host "ERROR: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        $sr = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        Write-Host "BODY: $($sr.ReadToEnd())"
    }
}

# Test 5: GET /rooms/guest/my-room
Write-Host "`n=== Test 5: GET /rooms/guest/my-room ==="
try {
    $r = Invoke-WebRequest -Uri "$BASE/rooms/guest/my-room" -Method GET -Headers @{Authorization="Bearer $CUSTOMER_TOKEN"} -UseBasicParsing -TimeoutSec 10
    Write-Host "STATUS: $($r.StatusCode)"
    Write-Host "BODY: $($r.Content.Substring(0, [Math]::Min(300, $r.Content.Length)))"
} catch {
    Write-Host "ERROR: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        $sr = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        Write-Host "BODY: $($sr.ReadToEnd())"
    }
}

# Test 6: GET /rooms (list)
Write-Host "`n=== Test 6: GET /rooms ==="
try {
    $r = Invoke-WebRequest -Uri "$BASE/rooms" -Method GET -Headers @{Authorization="Bearer $HOTEL_ADMIN_TOKEN"} -UseBasicParsing -TimeoutSec 10
    Write-Host "STATUS: $($r.StatusCode)"
    Write-Host "BODY: $($r.Content.Substring(0, [Math]::Min(300, $r.Content.Length)))"
} catch {
    Write-Host "ERROR: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        $sr = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        Write-Host "BODY: $($sr.ReadToEnd())"
    }
}

# Test 7: GET /rooms/1
Write-Host "`n=== Test 7: GET /rooms/1 ==="
try {
    $r = Invoke-WebRequest -Uri "$BASE/rooms/1" -Method GET -Headers @{Authorization="Bearer $HOTEL_ADMIN_TOKEN"} -UseBasicParsing -TimeoutSec 10
    Write-Host "STATUS: $($r.StatusCode)"
    Write-Host "BODY: $($r.Content.Substring(0, [Math]::Min(300, $r.Content.Length)))"
} catch {
    Write-Host "ERROR: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        $sr = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        Write-Host "BODY: $($sr.ReadToEnd())"
    }
}

# Test 8: POST /reviews
Write-Host "`n=== Test 8: POST /reviews ==="
$reviewBody = '{"hotel_id":1,"score":4.5,"content":"test review"}'
try {
    $r = Invoke-WebRequest -Uri "$BASE/reviews" -Method POST -Headers @{Authorization="Bearer $CUSTOMER_TOKEN"; "Content-Type"="application/json"} -Body ([System.Text.Encoding]::UTF8.GetBytes($reviewBody)) -UseBasicParsing -TimeoutSec 15
    Write-Host "STATUS: $($r.StatusCode)"
    Write-Host "BODY: $($r.Content.Substring(0, [Math]::Min(300, $r.Content.Length)))"
} catch {
    Write-Host "ERROR: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        $sr = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        Write-Host "BODY: $($sr.ReadToEnd())"
    }
}

# Test 9: MQTT send with proper body
Write-Host "`n=== Test 9: POST /mqtt/send ==="
$mqttBody = '{"topic":"hotel/test","message":"hello"}'
try {
    $r = Invoke-WebRequest -Uri "$BASE/mqtt/send" -Method POST -Headers @{Authorization="Bearer $HOTEL_ADMIN_TOKEN"; "Content-Type"="application/json"} -Body ([System.Text.Encoding]::UTF8.GetBytes($mqttBody)) -UseBasicParsing -TimeoutSec 15
    Write-Host "STATUS: $($r.StatusCode)"
    Write-Host "BODY: $($r.Content)"
} catch {
    Write-Host "ERROR: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        $sr = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        Write-Host "BODY: $($sr.ReadToEnd())"
    }
}

# Test 10: Device beep test
Write-Host "`n=== Test 10: POST /devices/test-beep ==="
$beepBody = '{"device_id":"ROO_AF22DA59AFA8"}'
try {
    $r = Invoke-WebRequest -Uri "$BASE/devices/test-beep" -Method POST -Headers @{Authorization="Bearer $HOTEL_ADMIN_TOKEN"; "Content-Type"="application/json"} -Body ([System.Text.Encoding]::UTF8.GetBytes($beepBody)) -UseBasicParsing -TimeoutSec 15
    Write-Host "STATUS: $($r.StatusCode)"
    Write-Host "BODY: $($r.Content)"
} catch {
    Write-Host "ERROR: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        $sr = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        Write-Host "BODY: $($sr.ReadToEnd())"
    }
}

# Test 11: Get existing booking by ID
Write-Host "`n=== Test 11: GET /bookings/251 ==="
try {
    $r = Invoke-WebRequest -Uri "$BASE/bookings/251" -Method GET -Headers @{Authorization="Bearer $CUSTOMER_TOKEN"} -UseBasicParsing -TimeoutSec 10
    Write-Host "STATUS: $($r.StatusCode)"
    Write-Host "BODY: $($r.Content.Substring(0, [Math]::Min(300, $r.Content.Length)))"
} catch {
    Write-Host "ERROR: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        $sr = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        Write-Host "BODY: $($sr.ReadToEnd())"
    }
}
