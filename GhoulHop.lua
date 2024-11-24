local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

-- URL ของ API ที่เก็บข้อมูล AllBoss/Ghoul
local serverUrl = "http://223.205.84.47:5000/AllBoss/Ghoul" -- แทนที่ <Your_Public_IP> ด้วย IP ของคุณ

-- ฟังก์ชันสำหรับการดึงข้อมูลจาก API
local function getGhoulDataFromAPI(url)
    print("กำลังดึงข้อมูลจาก API...")
    local success, response = pcall(function() return game:HttpGet(url) end)
    if success and response then
        local data = HttpService:JSONDecode(response)
        if data then
            print("ข้อมูลทั้งหมดที่ได้รับจาก API:", HttpService:JSONEncode(data))
            return data
        else
            warn("ไม่พบข้อมูลในโหนด AllBoss/Ghoul")
            return nil
        end
    else
        warn("ไม่สามารถดึงข้อมูลจาก API ได้")
        return nil
    end
end

-- ฟังก์ชันสำหรับสุ่มเลือกโหนดที่มี players น้อยกว่า 12
local function selectRandomNode(nodes)
    local validNodes = {}
    print("กำลังตรวจสอบโหนดที่มี players น้อยกว่า 12...")

    for key, node in pairs(nodes) do
        print("ตรวจสอบโหนด:", key, node)
        
        local jobId = node.job_id
        local playersData = node.players
        print("ตรวจสอบ job_id:", jobId)
        print("ตรวจสอบ players (ก่อนการจัดการ):", playersData)
        
        if playersData then
            playersData = playersData:gsub("%D", "")
            print("ตรวจสอบ players (หลังการจัดการ):", playersData)

            local playersCount = tonumber(playersData:sub(1, -3))
            local maxPlayers = tonumber(playersData:sub(-2))
            print("จำนวนผู้เล่นในโหนดนี้:", playersCount, "/", maxPlayers)

            if playersCount and maxPlayers and playersCount < 12 then
                table.insert(validNodes, node)
                print("โหนดนี้ตรงตามเงื่อนไข, เพิ่มลงในรายการ validNodes")
            else
                print("โหนดนี้ไม่ตรงตามเงื่อนไขจำนวนผู้เล่น")
            end
        else
            print("โหนดนี้ไม่มีข้อมูล players")
        end
    end

    if #validNodes > 0 then
        local randomIndex = math.random(1, #validNodes)
        print("พบโหนดที่ตรงตามเงื่อนไข, สุ่มเลือกโหนดที่ตำแหน่ง:", randomIndex)
        return validNodes[randomIndex]
    else
        print("ไม่พบโหนดที่ตรงตามเงื่อนไขทั้งหมด")
        return nil
    end
end

local function attemptTeleport(player)
    while true do
        local ghoulData = getGhoulDataFromAPI(serverUrl)
        if not ghoulData then
            print("ไม่สามารถดึงข้อมูลเซิร์ฟเวอร์ได้ รอ 10 วินาทีก่อนลองใหม่...")
            wait(10)
        else
            local selectedNode = selectRandomNode(ghoulData)
            if selectedNode and selectedNode.job_id then
                print("กำลังพยายามเทเลพอร์ตไปยังเซิร์ฟเวอร์ที่มี job_id: " .. selectedNode.job_id)
                
                -- ครอบการเทเลพอร์ตใน pcall เพื่อจัดการข้อผิดพลาดและวนลูปใหม่
                local success, errorMsg = pcall(function()
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, selectedNode.job_id, player)
                end)
                
                if success then
                    print("เทเลพอร์ตสำเร็จไปยังเซิร์ฟเวอร์ที่มี job_id: " .. selectedNode.job_id)
                    return -- ออกจากฟังก์ชันเมื่อสำเร็จ
                else
                    print("การเทเลพอร์ตล้มเหลว: " .. (errorMsg or "ไม่ทราบสาเหตุ"))
                    if errorMsg and errorMsg:find("GameFull") then
                        print("เซิร์ฟเวอร์เต็ม, กำลังลองเซิร์ฟเวอร์ใหม่ทันที...")
                    else
                        print("เกิดข้อผิดพลาดที่ไม่ใช่ 'GameFull' รอ 5 วินาทีก่อนลองใหม่...")
                        wait(5)  -- รอ 5 วินาทีก่อนลองใหม่
                    end
                end
            else
                print("ไม่พบเซิร์ฟเวอร์ที่ตรงตามเงื่อนไข รอ 10 วินาทีก่อนลองใหม่...")
                wait(10)
            end
        end
        wait(5)  -- เพิ่มการหน่วงเวลาสำหรับการวนลูป
    end
end

-- ฟังก์ชันหลักสำหรับตรวจสอบและเทเลพอร์ต
local function checkForCursedCaptainAndTeleport()
    repeat
        local player = Players.LocalPlayer
        local backpack = player:FindFirstChild("Backpack")
        if backpack and backpack:FindFirstChild("Hellfire Torch") then
            print("พบเครื่องมือ 'Hellfire Torch' ใน Backpack หยุดการทำงาน")
            return
        end

        local raceValue = player:FindFirstChild("Data") and player.Data:FindFirstChild("Race") and player.Data.Race.Value
        if raceValue == "Ghoul" then
            print("พบว่า Race เป็น 'Ghoul', หยุดการทำงาน")
            return
        end

        local cursedCaptain = Workspace:FindFirstChild("Enemies") and Workspace.Enemies:FindFirstChild("Cursed Captain")
        if not cursedCaptain then
            print("ไม่พบ 'Cursed Captain' ใน Workspace, กำลังเตรียมเทเลพอร์ต...")
            attemptTeleport(player)
            return
        else
            print("พบ 'Cursed Captain' ใน Workspace, รอ 10 วินาทีก่อนตรวจสอบอีกครั้ง...")
        end
        wait(10)
    until false
end

wait(15)

checkForCursedCaptainAndTeleport()
