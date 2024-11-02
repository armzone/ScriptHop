local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

-- URL ของ Firebase ที่เก็บข้อมูล AllBoss/Ghoul
local serverUrl = "https://jobid-1e3dc-default-rtdb.asia-southeast1.firebasedatabase.app/AllBoss/Ghoul.json"

-- ฟังก์ชันสำหรับการดึงข้อมูลจาก Firebase
local function getGhoulDataFromFirebase(url)
    print("กำลังดึงข้อมูลจาก Firebase...")
    local success, response = pcall(function() return game:HttpGet(url) end)
    if success and response then
        local data = HttpService:JSONDecode(response)
        if data then
            print("ข้อมูลทั้งหมดที่ได้รับจาก Firebase:", HttpService:JSONEncode(data))
            return data
        else
            warn("ไม่พบข้อมูลในโหนด AllBoss/Ghoul")
            return nil
        end
    else
        warn("ไม่สามารถดึงข้อมูลจาก Firebase ได้")
        return nil
    end
end

-- ฟังก์ชันสำหรับสุ่มเลือกโหนดที่มี players น้อยกว่า 12
local function selectRandomNode(nodes)
    local validNodes = {}
    print("กำลังตรวจสอบโหนดที่มี players น้อยกว่า 12...")

    for key, node in pairs(nodes) do
        print("ตรวจสอบโหนด:", key, node)
        
        -- เข้าถึงข้อมูลโหนดย่อยที่มี job_id และ players
        local jobId = node.job_id
        local playersData = node.players
        print("ตรวจสอบ job_id:", jobId)
        print("ตรวจสอบ players (ก่อนการจัดการ):", playersData)
        
        if playersData then
            -- ลบ \n และอักขระอื่นๆ ที่ไม่ใช่ตัวเลขออกจาก playersData
            playersData = playersData:gsub("%D", "")  -- ลบอักขระที่ไม่ใช่ตัวเลข
            print("ตรวจสอบ players (หลังการจัดการ):", playersData)

            -- แปลง playersData เป็นจำนวนผู้เล่นทั้งหมด
            local playersCount = tonumber(playersData:sub(1, -3))  -- เอาเลข 2 ตัวแรกเป็นจำนวนผู้เล่น
            local maxPlayers = tonumber(playersData:sub(-2))  -- เอาเลข 2 ตัวสุดท้ายเป็นจำนวนผู้เล่นสูงสุด
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

-- ฟังก์ชันหลักสำหรับตรวจสอบและเทเลพอร์ต
local function checkForCursedCaptainAndTeleport()
    while true do
        -- ตรวจสอบว่าผู้เล่นมีเครื่องมือ "Hellfire Torch" หรือไม่
        local player = Players.LocalPlayer
        local backpack = player:FindFirstChild("Backpack")
        if backpack and backpack:FindFirstChild("Hellfire Torch") then
            print("พบเครื่องมือ 'Hellfire Torch' ใน Backpack หยุดการทำงาน")
            return -- หยุดฟังก์ชันนี้และไม่ทำการเทเลพอร์ต
        end

        -- ตรวจสอบค่าว่า raceValue เป็น "Ghoul" หรือไม่
        local raceValue = player:FindFirstChild("Data") and player.Data:FindFirstChild("Race") and player.Data.Race.Value
        if raceValue == "Ghoul" then
            print("พบว่า Race เป็น 'Ghoul', หยุดการทำงาน")
            return -- หยุดฟังก์ชันนี้และไม่ทำการเทเลพอร์ต
        end

        -- ตรวจสอบว่ามี "Cursed Captain" อยู่ใน Workspace หรือไม่
        local cursedCaptain = Workspace:FindFirstChild("Enemies") and Workspace.Enemies:FindFirstChild("Cursed Captain")
        if not cursedCaptain then
            print("ไม่พบ 'Cursed Captain' ใน Workspace, กำลังเตรียมเทเลพอร์ต...")
            
            local ghoulData = getGhoulDataFromFirebase(serverUrl)

            if ghoulData then
                local selectedNode = selectRandomNode(ghoulData)

                if selectedNode and selectedNode.job_id then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, selectedNode.job_id, player)
                    print("กำลังเทเลพอร์ตไปยังเซิร์ฟเวอร์ที่มี job_id: " .. selectedNode.job_id)
                    return -- ออกจากลูปหลังจากเทเลพอร์ตสำเร็จ
                else
                    print("ไม่พบเซิร์ฟเวอร์ที่ตรงตามเงื่อนไข, รอ 10 วินาทีก่อนตรวจสอบอีกครั้ง...")
                end
            else
                warn("ไม่สามารถดึงข้อมูลจาก Firebase หรือข้อมูลไม่ถูกต้อง")
            end
        else
            print("พบ 'Cursed Captain' ใน Workspace, รอ 10 วินาทีก่อนตรวจสอบอีกครั้ง...")
        end
        wait(10) -- รอ 10 วินาทีก่อนตรวจสอบอีกครั้ง
    end
end

-- เรียกฟังก์ชันหลัก
checkForCursedCaptainAndTeleport()
