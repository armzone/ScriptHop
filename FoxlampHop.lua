local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

-- รอ 30 วิก่อนที่สคริปต์จะเริ่มทำงาน
wait(30)

local serverUrl = "https://jobid-1e3dc-default-rtdb.asia-southeast1.firebasedatabase.app/banana_hub_notifications/latest_messages.json"
local switchingServer = false  -- ตัวแปรสำหรับควบคุมสถานะการเปลี่ยนเซิร์ฟเวอร์

-- ฟังก์ชันสำหรับตรวจสอบสถานะพระจันทร์และเวลาสำหรับ Sea3
local function CheckMoonAndTimeForSea3()
    local function MoonTextureId()
        return game:GetService("Lighting").Sky.MoonTextureId
    end

    local function CheckMoon()
        local moonIds = {
            ["9709150401"] = "Bad Moon",
            ["9709150086"] = "Bad Moon",
            ["9709149680"] = "Bad Moon",
            ["9709149431"] = "Full Moon",
            ["15493317929"] = "Full Moon",
            ["9709149052"] = "Next Night",
            ["9709143733"] = "Bad Moon",
            ["9709139597"] = "Bad Moon",
            ["9709135895"] = "Bad Moon",
        }
        
        local moonreal = MoonTextureId()
        local normalizedMoonId = moonreal:match("%d+$")
        local moonStatus = moonIds[normalizedMoonId] or "Unknown Moon"
        
        return moonStatus
    end
    
    local function calculateMoonPhase()
        local c = game.Lighting
        local ao = c.ClockTime
        local moonStatus = CheckMoon()

        if moonStatus == "Full Moon" and ao <= 5 then
            return "( Will End Moon In " .. math.floor(5 - ao) .. " Minutes )"
        elseif moonStatus == "Full Moon" and (ao > 5 and ao < 12) then
            return "( Fake Moon )"
        elseif moonStatus == "Full Moon" and (ao > 12 and ao < 18) then
            return "( Will Full Moon In " .. math.floor(18 - ao) .. " Minutes )"
        elseif moonStatus == "Full Moon" and (ao > 18 and ao <= 24) then
            return "( Will End Moon In " .. math.floor(24 + 6 - ao) .. " Minutes )"
        elseif moonStatus == "Next Night" and ao < 12 then
            return "( Will Full Moon In " .. math.floor(18 - ao) .. " Minutes )"
        elseif moonStatus == "Next Night" and ao > 12 then
            return "( Will Full Moon In " .. math.floor(18 + 12 - ao) .. " Minutes )"
        end
        
        return "( Unknown Moon Status )"
    end

    return calculateMoonPhase()
end

-- ฟังก์ชันสำหรับดึงข้อมูลจาก Firebase
local function getDataFromFirebase(url)
    local success, response = pcall(function() return game:HttpGet(url) end)
    if success and response then
        local data = HttpService:JSONDecode(response)
        return data
    else
        warn("ไม่สามารถดึงข้อมูลจาก Firebase ได้:", response)
        return nil
    end
end

-- ฟังก์ชันสำหรับเลือกโหนดที่ดีที่สุด
local function selectBestNode(nodes)
    local bestNode = nil
    local leastPlayers = math.huge

    for _, node in pairs(nodes) do
        if node.player_count then
            local playersCount = tonumber(node.player_count)
            if playersCount and playersCount < leastPlayers then
                leastPlayers = playersCount
                bestNode = node
            end
        end
    end

    if bestNode and bestNode.time_till_full_moon then
        local time = tonumber(bestNode.time_till_full_moon:match("%d+%.?%d*"))
        if time and time <= 10 then
            return bestNode
        end
    end

    return nil
end

-- ฟังก์ชันสำหรับตรวจสอบว่าเซิร์ฟเวอร์ปัจจุบันเหมาะสมหรือไม่
local function isCurrentServerSuitable()
    local moonPhaseInfo = CheckMoonAndTimeForSea3()

    -- ตรวจสอบเงื่อนไขของพระจันทร์และเวลาปัจจุบัน
    local moonEndIn = moonPhaseInfo:match("Will End Moon In (%d+) Minutes")
    local fullMoonIn = moonPhaseInfo:match("Will Full Moon In (%d+) Minutes")

    -- ถ้า Full Moon เหลือเวลาน้อยกว่า 2 นาที จะถือว่าเซิร์ฟเวอร์ไม่เหมาะสม
    if moonEndIn and tonumber(moonEndIn) < 2 then
        print("Full Moon เหลือน้อยกว่า 2 นาที เซิร์ฟเวอร์ไม่เหมาะสม")
        return false
    end

    -- ถ้า Full Moon จะมาถึงในไม่เกิน 10 นาที ถือว่าเซิร์ฟเวอร์เหมาะสม
    if (moonEndIn and tonumber(moonEndIn) >= 2) or (fullMoonIn and tonumber(fullMoonIn) <= 10) then
        print("เซิร์ฟเวอร์ปัจจุบันตรงตามเงื่อนไขแล้ว")
        return true
    else
        print("เซิร์ฟเวอร์ปัจจุบันไม่ตรงตามเงื่อนไข")
        return false
    end
end

-- ฟังก์ชันหลักสำหรับตรวจสอบและเทเลพอร์ตไปยังเซิร์ฟเวอร์ที่เหมาะสม
local function checkForBestNodeAndTeleport(forceSwitch)
    if switchingServer then return end
    switchingServer = true  -- ตั้งค่าสถานะการเทเลพอร์ต

    -- ตรวจสอบเฉพาะเงื่อนไขของเซิร์ฟเวอร์ปัจจุบัน ถ้าไม่ได้บังคับให้เปลี่ยนเซิร์ฟเวอร์
    if not forceSwitch and isCurrentServerSuitable() then
        print("เซิร์ฟเวอร์ปัจจุบันตรงตามเงื่อนไขแล้ว ไม่จำเป็นต้องย้ายเซิร์ฟเวอร์")
        switchingServer = false
        return
    end

    local latestMessages = getDataFromFirebase(serverUrl)
    if latestMessages then
        local selectedNode = selectBestNode(latestMessages)
        if selectedNode and selectedNode.jobid then
            print("กำลังเทเลพอร์ตไปยังเซิร์ฟเวอร์ใหม่ jobid:", selectedNode.jobid)
            
            local success, err = pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, selectedNode.jobid, Players.LocalPlayer)
            end)
            
            if not success then
                warn("เกิดข้อผิดพลาดในการเทเลพอร์ต:", err)
                switchingServer = false  -- รีเซ็ตสถานะเพื่อให้สามารถลองใหม่ได้
            end
        else
            print("ไม่พบเซิร์ฟเวอร์ที่ตรงตามเงื่อนไข, กำลังรอ 10 วินาทีก่อนตรวจสอบอีกครั้ง...")
            switchingServer = false
            wait(10)
        end
    else
        warn("ไม่พบข้อมูลจาก Firebase หรือไม่สามารถดึงข้อมูลได้")
        switchingServer = false
        wait(10)
    end
end

-- ตรวจสอบการเพิ่มข้อความ "The Blue Moon fades away..."
playerGui.DescendantAdded:Connect(function(descendant)
    if (descendant:IsA("TextLabel") or descendant:IsA("TextButton")) and descendant.Text == "The Blue Moon fades away..." then
        print("พบข้อความ 'The Blue Moon fades away...' ทำการเลือกเซิร์ฟเวอร์ใหม่ทันที")
        checkForBestNodeAndTeleport(true)  -- บังคับให้ย้ายเซิร์ฟเวอร์ใหม่ทันที
    end
end)

-- เริ่มต้นตรวจสอบและเทเลพอร์ตหากพบเงื่อนไขที่กำหนด
checkForBestNodeAndTeleport(false)
