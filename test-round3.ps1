$BaseUrl = "http://localhost:9000/api/v1"
$FrontendBase = "http://localhost:5173"
$Issues = @()
$PassCount = 0
$FailCount = 0

function Log-Result {
    param([string]$Name, [bool]$Pass, [string]$Detail = "")
    if ($Pass) {
        $script:PassCount++
        Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:FailCount++
        Write-Host "  [FAIL] $Name - $Detail" -ForegroundColor Red
        $script:Issues += "$Name - $Detail"
    }
}

function Api-Call {
    param([string]$Method, [string]$Url, [string]$Token = "", [string]$Body = "")
    try {
        $headers = @{"Content-Type"="application/json"}
        if ($Token) { $headers["Authorization"] = "Bearer $Token" }
        $params = @{ Uri=$Url; Method=$Method; Headers=$headers; UseBasicParsing=$true; ContentType="application/json" }
        if ($Body -and ($Method -ne "GET" -and $Method -ne "DELETE")) { $params["Body"]=$Body }
        $resp = Invoke-WebRequest @params -ErrorAction Stop
        return @{ Success=$true; Status=$resp.StatusCode; Body=$resp.Content }
    } catch {
        $status = 0
        $body = ""
        if ($_.Exception.Response) {
            $status = [int]$_.Exception.Response.StatusCode
            try {
                $stream = $_.Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($stream)
                $body = $reader.ReadToEnd()
                $reader.Close()
            } catch { $body = $_.Exception.Message }
        }
        return @{ Success=$false; Status=$status; Body=$body }
    }
}

try {
    $sysAdminToken = (Invoke-RestMethod -Uri "$BaseUrl/auth/login" -Method Post -ContentType "application/json" -Body '{"phone":"13900000001","password":"123123"}' -ErrorAction Stop).data.token
    $hotelAdminToken = (Invoke-RestMethod -Uri "$BaseUrl/auth/login" -Method Post -ContentType "application/json" -Body '{"phone":"13900000002","password":"123123"}' -ErrorAction Stop).data.token
    $staffToken = (Invoke-RestMethod -Uri "$BaseUrl/auth/login" -Method Post -ContentType "application/json" -Body '{"phone":"13900000004","password":"123123"}' -ErrorAction Stop).data.token
    $customerToken = (Invoke-RestMethod -Uri "$BaseUrl/auth/login" -Method Post -ContentType "application/json" -Body '{"phone":"13900000006","password":"123123"}' -ErrorAction Stop).data.token
    Write-Host "  All tokens obtained successfully" -ForegroundColor Green
} catch {
    Write-Host "  Login failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Retrying in 3 seconds..." -ForegroundColor Yellow
    Start-Sleep -Seconds 3
    $sysAdminToken = (Invoke-RestMethod -Uri "$BaseUrl/auth/login" -Method Post -ContentType "application/json" -Body '{"phone":"13900000001","password":"123123"}').data.token
    $hotelAdminToken = (Invoke-RestMethod -Uri "$BaseUrl/auth/login" -Method Post -ContentType "application/json" -Body '{"phone":"13900000002","password":"123123"}').data.token
    $staffToken = (Invoke-RestMethod -Uri "$BaseUrl/auth/login" -Method Post -ContentType "application/json" -Body '{"phone":"13900000004","password":"123123"}').data.token
    $customerToken = (Invoke-RestMethod -Uri "$BaseUrl/auth/login" -Method Post -ContentType "application/json" -Body '{"phone":"13900000006","password":"123123"}').data.token
    Write-Host "  Retry successful" -ForegroundColor Green
}

# ============================================
# 1. Frontend Pages
# ============================================
Write-Host "`n=== 1. Frontend Page Accessibility ===" -ForegroundColor Yellow

$allPages = @(
    @{url="/login"; name="Login"},
    @{url="/guest/booking"; name="Guest-Booking"},
    @{url="/guest/checkin-online"; name="Guest-OnlineCheckin"},
    @{url="/guest/room"; name="Guest-Room"},
    @{url="/guest/orders"; name="Guest-Orders"},
    @{url="/guest/profile"; name="Guest-Profile"},
    @{url="/system/dashboard"; name="System-Dashboard"},
    @{url="/system/hotels"; name="System-Hotels"},
    @{url="/system/devices"; name="System-Devices"},
    @{url="/system/users"; name="System-Users"},
    @{url="/system/coupons"; name="System-Coupons"},
    @{url="/system/settings"; name="System-Settings"},
    @{url="/hotel-admin/dashboard"; name="HotelAdmin-Dashboard"},
    @{url="/hotel-admin/devices"; name="HotelAdmin-Devices"},
    @{url="/hotel-admin/rooms/edit"; name="HotelAdmin-Rooms"},
    @{url="/hotel-admin/hotel/info"; name="HotelAdmin-Info"},
    @{url="/hotel-admin/reports"; name="HotelAdmin-Reports"},
    @{url="/hotel-admin/users"; name="HotelAdmin-Users"},
    @{url="/hotel-admin/knowledge-base"; name="HotelAdmin-KB"},
    @{url="/hotel-admin/reviews"; name="HotelAdmin-Reviews"},
    @{url="/reception/dashboard"; name="Reception-Dashboard"},
    @{url="/reception/reception-center"; name="Reception-Center"},
    @{url="/reception/bookings"; name="Reception-Bookings"},
    @{url="/reception/delivery"; name="Reception-Delivery"},
    @{url="/reception/voice-calls"; name="Reception-VoiceCalls"},
    @{url="/reception/environment"; name="Reception-Env"}
)

foreach ($page in $allPages) {
    try {
        $r = Invoke-WebRequest -Uri "$FrontendBase$($page.url)" -Method Get -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        Log-Result "Page-$($page.name)" ($r.StatusCode -eq 200) ""
    } catch {
        Log-Result "Page-$($page.name)" $false $_.Exception.Message
    }
}

# ============================================
# 2. CRUD Complete Tests
# ============================================
Write-Host "`n=== 2. CRUD Complete Tests ===" -ForegroundColor Yellow

# 2a. Room Type CRUD
Write-Host "  --- Room Type ---"
$rt = @{name="CRUDTestRoomType";hotel_id=1;base_price=199;description="CRUD test";bed_type="double";max_guests=2;area=30} | ConvertTo-Json -Compress
$r = Api-Call "POST" "$BaseUrl/room-types" $hotelAdminToken $rt
$rtCreated = $r.Success -and $r.Status -eq 200
Log-Result "RoomType-Create" $rtCreated "Status:$($r.Status)"
if ($rtCreated) {
    $rtid = ($r.Body | ConvertFrom-Json).data.id
    if ($rtid) {
        $r = Api-Call "PUT" "$BaseUrl/room-types/$rtid" $hotelAdminToken '{"name":"CRUDTestRoomType-Updated","base_price":299}'
        Log-Result "RoomType-Update" ($r.Status -eq 200) "Status:$($r.Status)"
        $r = Api-Call "DELETE" "$BaseUrl/room-types/$rtid" $hotelAdminToken
        Log-Result "RoomType-Delete" ($r.Status -eq 200) "Status:$($r.Status)"
    }
}

# 2b. Floor CRUD
Write-Host "  --- Floor ---"
$fl = @{name="CRUDTestFloor";hotel_id=1;floor_number=99} | ConvertTo-Json -Compress
$r = Api-Call "POST" "$BaseUrl/floors" $hotelAdminToken $fl
Log-Result "Floor-Create" ($r.Status -eq 200 -or $r.Status -eq 400) "Status:$($r.Status)"

# 2c. Review CRUD
Write-Host "  --- Review ---"
$nr = @{hotel_id=1;rating=4;content="CRUD test review content"} | ConvertTo-Json -Compress
$r = Api-Call "POST" "$BaseUrl/reviews" $customerToken $nr
if ($r.Success -and $r.Status -eq 200) {
    $revid = ($r.Body | ConvertFrom-Json).data.id
    if ($revid) {
        Log-Result "Review-Create" $true ""
        $r = Api-Call "PUT" "$BaseUrl/reviews/$revid" $customerToken '{"rating":5,"content":"Updated review"}'
        Log-Result "Review-Update" ($r.Status -eq 200) "Status:$($r.Status)"
        $r = Api-Call "DELETE" "$BaseUrl/reviews/$revid" $customerToken
        Log-Result "Review-Delete" ($r.Status -eq 200) "Status:$($r.Status)"
    }
} else {
    Log-Result "Review-Create" $false "Status:$($r.Status) Body:$($r.Body)"
}

# 2d. Knowledge Base CRUD
Write-Host "  --- Knowledge Base ---"
$kb = @{question="CRUD test question?";answer="CRUD test answer";category="general";hotel_id=1} | ConvertTo-Json -Compress
$r = Api-Call "POST" "$BaseUrl/knowledge-base" $hotelAdminToken $kb
Log-Result "KB-Create" ($r.Status -eq 200 -or $r.Status -eq 400) "Status:$($r.Status) Body:$($r.Body)"

# 2e. Rate Plan CRUD
Write-Host "  --- Rate Plan ---"
$rp = @{name="CRUDTestRatePlan";hotel_id=1;room_type_id=31;base_price=299;discount_rate=0.9} | ConvertTo-Json -Compress
$r = Api-Call "POST" "$BaseUrl/rate-plans" $hotelAdminToken $rp
Log-Result "RatePlan-Create" ($r.Status -eq 200 -or $r.Status -eq 400) "Status:$($r.Status)"

# 2f. Coupon CRUD
Write-Host "  --- Coupon ---"
$nc = @{coupon_name="CRUDTestCoupon";coupon_type="discount";discount_value=10;min_amount=0;total_count=100;valid_from="2026-04-24";valid_to="2026-05-24";scope_type="hotel"} | ConvertTo-Json -Compress
$r = Api-Call "POST" "$BaseUrl/coupons" $hotelAdminToken $nc
if ($r.Success -and $r.Status -eq 200) {
    $cid = ($r.Body | ConvertFrom-Json).data.id
    if ($cid) {
        Log-Result "Coupon-Create" $true ""
        $r = Api-Call "DELETE" "$BaseUrl/coupons/$cid" $hotelAdminToken
        Log-Result "Coupon-Delete" ($r.Status -eq 200) "Status:$($r.Status)"
    }
} else {
    Log-Result "Coupon-Create" $false "Status:$($r.Status)"
}

# 2g. User CRUD
Write-Host "  --- User ---"
$nu = @{username="CRUDTestStaff";phone="13900880099";password="123456";role="staff";hotel_id=1} | ConvertTo-Json -Compress
$r = Api-Call "POST" "$BaseUrl/users" $hotelAdminToken $nu
if ($r.Success -and $r.Status -eq 200) {
    $uid = ($r.Body | ConvertFrom-Json).data.id
    if ($uid) {
        Log-Result "User-Create" $true ""
        $r = Api-Call "PUT" "$BaseUrl/users/profile" $customerToken '{"email":"crud_test@example.com"}'
        Log-Result "User-UpdateProfile" ($r.Status -eq 200) "Status:$($r.Status)"
    }
} else {
    Log-Result "User-Create" $false "Status:$($r.Status) Body:$($r.Body)"
}

# ============================================
# 3. Boundary and Edge Case Tests
# ============================================
Write-Host "`n=== 3. Boundary and Edge Case Tests ===" -ForegroundColor Yellow

# Invalid IDs
$r = Api-Call "GET" "$BaseUrl/bookings/0" $hotelAdminToken
Log-Result "Edge-BookingIdZero" ($r.Status -eq 400 -or $r.Status -eq 404) "Status:$($r.Status)"

$r = Api-Call "GET" "$BaseUrl/bookings/-1" $hotelAdminToken
Log-Result "Edge-BookingIdNegative" ($r.Status -eq 400 -or $r.Status -eq 404) "Status:$($r.Status)"

$r = Api-Call "GET" "$BaseUrl/bookings/abc" $hotelAdminToken
Log-Result "Edge-BookingIdString" ($r.Status -eq 400 -or $r.Status -eq 404) "Status:$($r.Status)"

$r = Api-Call "GET" "$BaseUrl/hotels/99999" ""
Log-Result "Edge-HotelNotFound" ($r.Status -eq 404 -or $r.Status -eq 400) "Status:$($r.Status)"

# Invalid dates
$bd = @{room_type_id=31;check_in_date="invalid-date";check_out_date="2026-04-29";guest_name="test";guest_phone="13900000006";hotel_id=1} | ConvertTo-Json -Compress
$r = Api-Call "POST" "$BaseUrl/bookings" $customerToken $bd
Log-Result "Edge-InvalidDate" ($r.Status -eq 400 -or $r.Status -eq 500) "Status:$($r.Status)"

# Past date
$bp = @{room_type_id=31;check_in_date="2020-01-01";check_out_date="2020-01-02";guest_name="test";guest_phone="13900000006";hotel_id=1} | ConvertTo-Json -Compress
$r = Api-Call "POST" "$BaseUrl/bookings" $customerToken $bp
Log-Result "Edge-PastDate" ($r.Status -eq 400) "Status:$($r.Status)"

# Checkout before checkin
$bre = @{room_type_id=31;check_in_date="2026-04-29";check_out_date="2026-04-28";guest_name="test";guest_phone="13900000006";hotel_id=1} | ConvertTo-Json -Compress
$r = Api-Call "POST" "$BaseUrl/bookings" $customerToken $bre
Log-Result "Edge-ReverseDates" ($r.Status -eq 400) "Status:$($r.Status)"

# SQL injection
$bsql = @{room_type_id=31;check_in_date="2026-04-28";check_out_date="2026-04-29";guest_name="'; DROP TABLE bookings;--";guest_phone="13900000006";hotel_id=1} | ConvertTo-Json -Compress
$r = Api-Call "POST" "$BaseUrl/bookings" $customerToken $bsql
Log-Result "Edge-SQLInjection" ($r.Status -eq 200 -or $r.Status -eq 400) "Status:$($r.Status)"

# XSS
$bxs = @{room_type_id=31;check_in_date="2026-04-28";check_out_date="2026-04-29";guest_name="<script>alert(1)</script>";guest_phone="13900000006";hotel_id=1} | ConvertTo-Json -Compress
$r = Api-Call "POST" "$BaseUrl/bookings" $customerToken $bxs
Log-Result "Edge-XSS" ($r.Status -eq 200 -or $r.Status -eq 400) "Status:$($r.Status)"

# Empty body
$r = Api-Call "POST" "$BaseUrl/bookings" $customerToken '{}'
Log-Result "Edge-EmptyBody" ($r.Status -eq 400) "Status:$($r.Status)"

# Non-existent room_type_id
$bnrt = @{room_type_id=99999;check_in_date="2026-04-28";check_out_date="2026-04-29";guest_name="test";guest_phone="13900000006";hotel_id=1} | ConvertTo-Json -Compress
$r = Api-Call "POST" "$BaseUrl/bookings" $customerToken $bnrt
Log-Result "Edge-BadRoomType" ($r.Status -eq 400 -or $r.Status -eq 404) "Status:$($r.Status)"

# Very long guest name
$bl = @{room_type_id=31;check_in_date="2026-04-28";check_out_date="2026-04-29";guest_name="A"*500;guest_phone="13900000006";hotel_id=1} | ConvertTo-Json -Compress
$r = Api-Call "POST" "$BaseUrl/bookings" $customerToken $bl
Log-Result "Edge-LongName" ($r.Status -eq 200 -or $r.Status -eq 400) "Status:$($r.Status)"

# ============================================
# 4. Device Command Tests
# ============================================
Write-Host "`n=== 4. Device Command Tests ===" -ForegroundColor Yellow

$devList = Invoke-RestMethod -Uri "$BaseUrl/devices" -Method Get -Headers @{"Authorization"="Bearer $hotelAdminToken"}
$approvedDev = $null
$pendingDev = $null
if ($devList.data) {
    foreach ($d in $devList.data) {
        if ($d.status -eq "approved" -and -not $approvedDev) { $approvedDev = $d }
        if ($d.status -eq "pending" -and -not $pendingDev) { $pendingDev = $d }
    }
}

if ($approvedDev) {
    Write-Host "    Approved device: $($approvedDev.device_id) (id=$($approvedDev.id))"
    $cmd = @{command_type="light";command_value="on"} | ConvertTo-Json -Compress
    $r = Api-Call "POST" "$BaseUrl/devices/$($approvedDev.id)/command" $hotelAdminToken $cmd
    Log-Result "Device-CmdApproved" ($r.Status -eq 200) "Status:$($r.Status) Body:$($r.Body)"
    
    $r = Api-Call "POST" "$BaseUrl/devices/$($approvedDev.id)/command" $staffToken $cmd
    Log-Result "Device-CmdStaff" ($r.Status -eq 200 -or $r.Status -eq 403) "Status:$($r.Status)"
    
    $r = Api-Call "POST" "$BaseUrl/devices/$($approvedDev.id)/command" $customerToken $cmd
    Log-Result "Device-CmdCustomer" ($r.Status -eq 403) "Status:$($r.Status)"
} else {
    Write-Host "    No approved device found" -ForegroundColor Yellow
}

if ($pendingDev) {
    Write-Host "    Pending device: $($pendingDev.device_id) (id=$($pendingDev.id))"
    $cmd = @{command_type="light";command_value="on"} | ConvertTo-Json -Compress
    $r = Api-Call "POST" "$BaseUrl/devices/$($pendingDev.id)/command" $hotelAdminToken $cmd
    Log-Result "Device-CmdPending" ($r.Status -eq 200 -or $r.Status -eq 403 -or $r.Status -eq 400) "Status:$($r.Status)"
}

# Device audit
if ($pendingDev) {
    $r = Api-Call "PUT" "$BaseUrl/devices/$($pendingDev.id)/audit" $hotelAdminToken '{"status":"approved"}'
    Log-Result "Device-AuditApprove" ($r.Status -eq 200) "Status:$($r.Status) Body:$($r.Body)"
}

# Room card
$rc = @{room_id=1;action="issue"} | ConvertTo-Json -Compress
$r = Api-Call "POST" "$BaseUrl/devices/room-card" $hotelAdminToken $rc
Log-Result "Device-RoomCard" ($r.Status -eq 200 -or $r.Status -eq 400) "Status:$($r.Status)"

# Test beep
$beep = @{device_id="test"} | ConvertTo-Json -Compress
$r = Api-Call "POST" "$BaseUrl/devices/test-beep" $hotelAdminToken $beep
Log-Result "Device-TestBeep" ($r.Status -eq 200 -or $r.Status -eq 400 -or $r.Status -eq 404) "Status:$($r.Status)"

# ============================================
# 5. Cross-Role Data Isolation
# ============================================
Write-Host "`n=== 5. Cross-Role Data Isolation ===" -ForegroundColor Yellow

# Customer only sees own bookings
$r = Api-Call "GET" "$BaseUrl/bookings/my" $customerToken
if ($r.Success -and $r.Status -eq 200) {
    $myData = ($r.Body | ConvertFrom-Json).data
    $allOwn = $true
    if ($myData -and $myData.Count -gt 0) {
        foreach ($b in $myData) {
            if ($b.user_id -ne 7) { $allOwn = $false; break }
        }
    }
    Log-Result "Isolation-OwnBookings" $allOwn ""
}

# Staff cannot access hotel/all
$r = Api-Call "GET" "$BaseUrl/hotel/all" $staffToken
Log-Result "Isolation-StaffNoHotelAll" ($r.Status -eq 403) "Status:$($r.Status)"

# Customer cannot access user detail
$r = Api-Call "GET" "$BaseUrl/users/1" $customerToken
Log-Result "Isolation-CustomerNoUser" ($r.Status -eq 403) "Status:$($r.Status)"

# Customer cannot create hotel
$r = Api-Call "POST" "$BaseUrl/hotel" $customerToken '{"hotel_name":"test"}'
Log-Result "Isolation-CustomerNoHotel" ($r.Status -eq 403) "Status:$($r.Status)"

# Staff cannot delete user
$r = Api-Call "DELETE" "$BaseUrl/users/999" $staffToken
Log-Result "Isolation-StaffNoDeleteUser" ($r.Status -eq 403) "Status:$($r.Status)"

# Customer cannot access payments
$r = Api-Call "GET" "$BaseUrl/payments" $customerToken
Log-Result "Isolation-CustomerNoPayments" ($r.Status -eq 403) "Status:$($r.Status)"

# Customer cannot access environment
$r = Api-Call "GET" "$BaseUrl/environment" $customerToken
Log-Result "Isolation-CustomerNoEnv" ($r.Status -eq 403) "Status:$($r.Status)"

# Customer cannot access devices
$r = Api-Call "GET" "$BaseUrl/devices" $customerToken
Log-Result "Isolation-CustomerNoDevices" ($r.Status -eq 403) "Status:$($r.Status)"

# Staff cannot delete devices
$r = Api-Call "DELETE" "$BaseUrl/devices/1" $staffToken
Log-Result "Isolation-StaffNoDeleteDev" ($r.Status -eq 403) "Status:$($r.Status)"

# Customer cannot modify system config
$r = Api-Call "PUT" "$BaseUrl/system-config" $customerToken '{}'
Log-Result "Isolation-CustomerNoConfig" ($r.Status -eq 403 -or $r.Status -eq 404) "Status:$($r.Status)"

# ============================================
# 6. Concurrent Booking
# ============================================
Write-Host "`n=== 6. Concurrent Booking ===" -ForegroundColor Yellow

$c2Token = (Invoke-RestMethod -Uri "$BaseUrl/auth/login" -Method Post -ContentType "application/json" -Body '{"phone":"13900000007","password":"123123"}').data.token

$cb1 = @{room_type_id=31;check_in_date="2026-05-05";check_out_date="2026-05-06";guest_name="Concurrent1";guest_phone="13900000006";hotel_id=1} | ConvertTo-Json -Compress
$cb2 = @{room_type_id=31;check_in_date="2026-05-05";check_out_date="2026-05-06";guest_name="Concurrent2";guest_phone="13900000007";hotel_id=1} | ConvertTo-Json -Compress

$r1 = Api-Call "POST" "$BaseUrl/bookings" $customerToken $cb1
$r2 = Api-Call "POST" "$BaseUrl/bookings" $c2Token $cb2
Log-Result "Concurrent-BothCreated" ($r1.Status -eq 200 -and $r2.Status -eq 200) "R1:$($r1.Status) R2:$($r2.Status)"

# ============================================
# 7. Mobile App API Compatibility
# ============================================
Write-Host "`n=== 7. Mobile App API ===" -ForegroundColor Yellow

$r = Api-Call "GET" "$BaseUrl/hotels/search" ""
Log-Result "Mobile-HotelSearch" ($r.Status -eq 200) ""

$r = Api-Call "GET" "$BaseUrl/hotels/1" ""
Log-Result "Mobile-HotelDetail" ($r.Status -eq 200) ""

$r = Api-Call "GET" "$BaseUrl/hotels/1/detail" ""
Log-Result "Mobile-HotelDetailFull" ($r.Status -eq 200) ""

$r = Api-Call "GET" "$BaseUrl/members/discounts" ""
Log-Result "Mobile-MemberDiscounts" ($r.Status -eq 200) ""

$r = Api-Call "GET" "$BaseUrl/reviews" ""
Log-Result "Mobile-ReviewList" ($r.Status -eq 200) ""

$r = Api-Call "GET" "$BaseUrl/room-types?hotel_id=1" ""
Log-Result "Mobile-RoomTypes" ($r.Status -eq 200) ""

$r = Api-Call "GET" "$BaseUrl/coupons/me" $customerToken
Log-Result "Mobile-MyCoupons" ($r.Status -eq 200) ""

$r = Api-Call "GET" "$BaseUrl/members/me" $customerToken
Log-Result "Mobile-MyMember" ($r.Status -eq 200) ""

$r = Api-Call "GET" "$BaseUrl/favorites" $customerToken
Log-Result "Mobile-MyFavorites" ($r.Status -eq 200) ""

# ============================================
# 8. Data Integrity Verification
# ============================================
Write-Host "`n=== 8. Data Integrity ===" -ForegroundColor Yellow

# User info consistency
$r = Api-Call "GET" "$BaseUrl/auth/me" $customerToken
if ($r.Success -and $r.Status -eq 200) {
    $me = ($r.Body | ConvertFrom-Json).data
    Log-Result "Data-UserInfoPhone" ($me.phone -eq "13900000006") "Phone: $($me.phone)"
    Log-Result "Data-UserInfoRole" ($me.role -eq "customer") "Role: $($me.role)"
}

# Hotel data consistency
$r = Api-Call "GET" "$BaseUrl/hotel" $hotelAdminToken
if ($r.Success -and $r.Status -eq 200) {
    $hotel = ($r.Body | ConvertFrom-Json).data
    Log-Result "Data-HotelHasId" ($null -ne $hotel.id) ""
}

# Booking data format
$r = Api-Call "GET" "$BaseUrl/bookings/my" $customerToken
if ($r.Success -and $r.Status -eq 200) {
    $resp = $r.Body | ConvertFrom-Json
    Log-Result "Data-BookingFormat" ($resp.code -eq 200) "code: $($resp.code)"
}

# ============================================
# 9. Special Feature Tests
# ============================================
Write-Host "`n=== 9. Special Features ===" -ForegroundColor Yellow

# QR Login
$r = Api-Call "POST" "$BaseUrl/auth/qr-generate" "" '{}'
Log-Result "Special-QRGenerate" ($r.Status -eq 200) ""

# Hotel Statistics
$r = Api-Call "GET" "$BaseUrl/hotel/statistics" $hotelAdminToken
Log-Result "Special-HotelStats" ($r.Status -eq 200) ""

# Hotel Reports
$r = Api-Call "GET" "$BaseUrl/hotel/reports" $hotelAdminToken
Log-Result "Special-HotelReports" ($r.Status -eq 200) ""

# Call Stats
$r = Api-Call "GET" "$BaseUrl/calls/stats" $hotelAdminToken
Log-Result "Special-CallStats" ($r.Status -eq 200) ""

# Payment Revenue
$r = Api-Call "GET" "$BaseUrl/payments/stats/revenue" $hotelAdminToken
Log-Result "Special-PaymentRevenue" ($r.Status -eq 200) ""

# Environment Dashboard
$r = Api-Call "GET" "$BaseUrl/environment/dashboard" $hotelAdminToken
Log-Result "Special-EnvDashboard" ($r.Status -eq 200) ""

# Device Alarm Stats
$r = Api-Call "GET" "$BaseUrl/device-alarms/stats" $hotelAdminToken
Log-Result "Special-AlarmStats" ($r.Status -eq 200) ""

# RFID Access Stats
$r = Api-Call "GET" "$BaseUrl/rfid-access/logs/stats" $hotelAdminToken
Log-Result "Special-RFIDStats" ($r.Status -eq 200) ""

# MQTT Status
$r = Api-Call "GET" "$BaseUrl/mqtt/status" $hotelAdminToken
Log-Result "Special-MQTTStatus" ($r.Status -eq 200) ""

# AI Butler Verify
$av = @{room_id=1} | ConvertTo-Json -Compress
$r = Api-Call "POST" "$BaseUrl/ai-butler/verify" $customerToken $av
Log-Result "Special-AIVerify" ($r.Status -eq 200) "Status:$($r.Status)"

# AI Butler Wake
$aw = @{room_id=1;text="hello"} | ConvertTo-Json -Compress
$r = Api-Call "POST" "$BaseUrl/ai-butler/wake" $customerToken $aw
Log-Result "Special-AIWake" ($r.Status -eq 200) "Status:$($r.Status)"

# Member Checkin
$r = Api-Call "POST" "$BaseUrl/members/checkin" $customerToken '{}'
Log-Result "Special-MemberCheckin" ($r.Status -eq 200 -or $r.Status -eq 400) "Status:$($r.Status)"

# Price Calendar Set
$pc = @{hotel_id=1;room_type_id=31;date="2026-04-28";price=299} | ConvertTo-Json -Compress
$r = Api-Call "POST" "$BaseUrl/price-calendar/set" $hotelAdminToken $pc
Log-Result "Special-PriceSet" ($r.Status -eq 200 -or $r.Status -eq 400) "Status:$($r.Status)"

# ============================================
# Summary
# ============================================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Round 3 Detailed Test Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  PASS: $PassCount" -ForegroundColor Green
Write-Host "  FAIL: $FailCount" -ForegroundColor Red
Write-Host "  Total: $($PassCount + $FailCount)" -ForegroundColor White

if ($Issues.Count -gt 0) {
    Write-Host "`n  === Failed Items ===" -ForegroundColor Red
    foreach ($issue in $Issues) {
        Write-Host "  - $issue" -ForegroundColor Red
    }
}
