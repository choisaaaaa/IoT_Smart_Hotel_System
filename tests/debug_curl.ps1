# Debug specific 404 endpoints using curl
$BASE = "http://localhost:9000/api/v1"
$STAFF_TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6OCwidXNlcm5hbWUiOiJyZWNlcHRpb25fMDEiLCJwaG9uZSI6IjEzOTAwMDAwMDA0Iiwicm9sZSI6InN0YWZmIiwiaG90ZWxfaWQiOjEsInBlcm1pc3Npb25zIjpbXSwiaWF0IjoxNzc2OTcwMTUzLCJleHAiOjE3NzcwNTY1NTMsImF1ZCI6ImlvdC1ob3RlbC11c2VycyIsImlzcyI6ImlvdC1ob3RlbC1zeXN0ZW0ifQ.CcMSBkLl7CAGwbNBd3i-qxml-wIc4NePwQc3D9k329Y"
$HOTEL_ADMIN_TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6MjAsInVzZXJuYW1lIjoiYWRtaW4xIiwicGhvbmUiOiIxMzkwMDAwMDAwMiIsInJvbGUiOiJob3RlbF9hZG1pbiIsImhvdGVsX2lkIjoxLCJwZXJtaXNzaW9ucyI6W10sImlhdCI6MTc3Njk3MDE1MywiZXhwIjoxNzc3MDU2NTUzLCJhdWQiOiJpb3QtaG90ZWwtdXNlcnMiLCJpc3MiOiJpb3QtaG90ZWwtc3lzdGVtIn0.YBlaLB4CSNbHRRQUnDBRmst3rF29kxDeKvfs8ZcfH3I"
$CUSTOMER_TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6NywidXNlcm5hbWUiOiJ5emoiLCJwaG9uZSI6IjEzOTAwMDAwMDA2Iiwicm9sZSI6ImN1c3RvbWVyIiwiaG90ZWxfaWQiOjAsInBlcm1pc3Npb25zIjpbXSwiaWF0IjoxNzc2OTcwMTUzLCJleHAiOjE3NzcwNTY1NTMsImF1ZCI6ImlvdC1ob3RlbC11c2VycyIsImlzcyI6ImlvdC1ob3RlbC1zeXN0ZW0ifQ.Yt8cKrr84Z2QYEtBOmKtUZdKhQTfUG6BTiblqL7r300"

Write-Host "=== Test 1: PUT /bookings/280/checkin ==="
curl.exe -s -w "`nHTTP_CODE:%{http_code}" -X PUT "$BASE/bookings/280/checkin" -H "Authorization: Bearer $STAFF_TOKEN" -H "Content-Type: application/json" -d '{"room_id":86,"guest_name":"Test","guest_phone":"13900000006"}'

Write-Host "`n`n=== Test 2: GET /rooms/86 ==="
curl.exe -s -w "`nHTTP_CODE:%{http_code}" "$BASE/rooms/86" -H "Authorization: Bearer $HOTEL_ADMIN_TOKEN"

Write-Host "`n`n=== Test 3: GET /rooms/1 ==="
curl.exe -s -w "`nHTTP_CODE:%{http_code}" "$BASE/rooms/1" -H "Authorization: Bearer $HOTEL_ADMIN_TOKEN"

Write-Host "`n`n=== Test 4: PATCH /rooms/1/status ==="
curl.exe -s -w "`nHTTP_CODE:%{http_code}" -X PATCH "$BASE/rooms/1/status" -H "Authorization: Bearer $HOTEL_ADMIN_TOKEN" -H "Content-Type: application/json" -d '{"status":"available"}'

Write-Host "`n`n=== Test 5: GET /rooms/guest/my-room ==="
curl.exe -s -w "`nHTTP_CODE:%{http_code}" "$BASE/rooms/guest/my-room" -H "Authorization: Bearer $CUSTOMER_TOKEN"

Write-Host "`n`n=== Test 6: GET /bookings/280 ==="
curl.exe -s -w "`nHTTP_CODE:%{http_code}" "$BASE/bookings/280" -H "Authorization: Bearer $STAFF_TOKEN"

Write-Host "`n`n=== Test 7: PUT /bookings/280/checkout ==="
curl.exe -s -w "`nHTTP_CODE:%{http_code}" -X PUT "$BASE/bookings/280/checkout" -H "Authorization: Bearer $STAFF_TOKEN"

Write-Host "`n`n=== Test 8: POST /reviews ==="
curl.exe -s -w "`nHTTP_CODE:%{http_code}" -X POST "$BASE/reviews" -H "Authorization: Bearer $CUSTOMER_TOKEN" -H "Content-Type: application/json" -d '{"hotel_id":1,"score":4.5,"content":"test review"}'

Write-Host "`n`n=== Test 9: GET /hotels/1/rooms/availability ==="
curl.exe -s -w "`nHTTP_CODE:%{http_code}" "$BASE/hotels/1/rooms/availability?check_in_date=2026-05-15&check_out_date=2026-05-16" -H "Authorization: Bearer $STAFF_TOKEN"

Write-Host "`n`n=== Test 10: POST /devices/test-beep ==="
curl.exe -s -w "`nHTTP_CODE:%{http_code}" -X POST "$BASE/devices/test-beep" -H "Authorization: Bearer $HOTEL_ADMIN_TOKEN" -H "Content-Type: application/json" -d '{"device_id":"ROO_AF22DA59AFA8"}'
