local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local serverUrl = "https://jobid-1e3dc-default-rtdb.asia-southeast1.firebasedatabase.app/banana_hub_notifications/latest_messages.json"
local switchingServer = false  -- ตัวแปรสำหรับควบคุมสถานะการเปลี่ยนเซิร์ฟเวอร์

local function getDataFromFirebase(url)
    local response = game:HttpGet(url)
    if response then
        local data = HttpService:JSONDecode(response)
        if data then
            return data
        else
            warn("ไม่พบข้อมูลในโหนดที่ต้องการ")
            return nil
        end
    else
        warn("ไม่สามารถดึงข้อมูลจาก Firebase ได้")
        return nil
    end
end

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

local function checkForBestNodeAndTeleport()
    while not switchingServer do
        local moonPhaseInfo = CheckMoonAndTimeForSea3()
        print("Moon Phase Info: " .. moonPhaseInfo)

        local moonEndIn = moonPhaseInfo:match("Will End Moon In (%d+) Minutes")
        local fullMoonIn = moonPhaseInfo:match("Will Full Moon In (%d+) Minutes")

        if (moonEndIn and tonumber(moonEndIn) >= 2) or (fullMoonIn and tonumber(fullMoonIn) <= 10) then
            print("อยู่ในเซิร์ฟเวอร์ที่เหมาะสมแล้ว")
        else
            print("ไม่อยู่ในเซิร์ฟเวอร์ที่เหมาะสม กำลังหาเซิร์ฟเวอร์ใหม่...")

            local latestMessages = getDataFromFirebase(serverUrl)
            if latestMessages then
                local selectedNode = selectBestNode(latestMessages)

                if selectedNode and selectedNode.jobid then
                    switchingServer = true  -- กำลังเปลี่ยนเซิร์ฟเวอร์
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, selectedNode.jobid, Players.LocalPlayer)
                    break
                else
                    print("ไม่พบเซิร์ฟเวอร์ที่ตรงตามเงื่อนไข, กำลังรอ 10 วินาทีก่อนตรวจสอบอีกครั้ง...")
                    wait(10)
                end
            else
                warn("ไม่พบข้อมูลจาก Firebase หรือไม่สามารถดึงข้อมูลได้")
                wait(10)
            end
        end

        wait(10)
    end
end

playerGui.DescendantAdded:Connect(function(descendant)
    if (descendant:IsA("TextLabel") or descendant:IsA("TextButton")) and descendant.Text == "The Blue Moon fades away..." then
        print("พบข้อความ 'The Blue Moon fades away...' ทำการเลือกเซิร์ฟเวอร์ใหม่ทันที")
        if not switchingServer then
            switchingServer = true  -- กำลังเปลี่ยนเซิร์ฟเวอร์
            checkForBestNodeAndTeleport()
        end
    end
end)

checkForBestNodeAndTeleport()
