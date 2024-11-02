local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local serverUrl = "https://jobid-1e3dc-default-rtdb.asia-southeast1.firebasedatabase.app/banana_hub_notifications/latest_messages.json"
local switchingServer = false  -- ตัวแปรสำหรับควบคุมสถานะการเปลี่ยนเซิร์ฟเวอร์

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

-- ฟังก์ชันหลักสำหรับตรวจสอบและเทเลพอร์ตไปยังเซิร์ฟเวอร์ที่เหมาะสม
local function checkForBestNodeAndTeleport()
    while not switchingServer do
        local latestMessages = getDataFromFirebase(serverUrl)
        if latestMessages then
            local selectedNode = selectBestNode(latestMessages)
            if selectedNode and selectedNode.jobid then
                switchingServer = true  -- ตั้งค่าสถานะการเทเลพอร์ต
                print("กำลังเทเลพอร์ตไปยังเซิร์ฟเวอร์ใหม่ jobid:", selectedNode.jobid)
                
                local success, err = pcall(function()
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, selectedNode.jobid, Players.LocalPlayer)
                end)
                
                if not success then
                    warn("เกิดข้อผิดพลาดในการเทเลพอร์ต:", err)
                    switchingServer = false  -- รีเซ็ตสถานะเพื่อให้สามารถลองใหม่ได้
                end
                break
            else
                print("ไม่พบเซิร์ฟเวอร์ที่ตรงตามเงื่อนไข, กำลังรอ 10 วินาทีก่อนตรวจสอบอีกครั้ง...")
                wait(10)
            end
        else
            warn("ไม่พบข้อมูลจาก Firebase หรือไม่สามารถดึงข้อมูลได้")
            wait(10)
        end
        wait(10)
    end
end

-- ตรวจสอบการเพิ่มข้อความ "The Blue Moon fades away..."
playerGui.DescendantAdded:Connect(function(descendant)
    if (descendant:IsA("TextLabel") or descendant:IsA("TextButton")) and descendant.Text == "The Blue Moon fades away..." then
        print("พบข้อความ 'The Blue Moon fades away...' ทำการเลือกเซิร์ฟเวอร์ใหม่ทันที")
        if not switchingServer then
            switchingServer = true
            checkForBestNodeAndTeleport()
        end
    end
end)

-- เริ่มต้นตรวจสอบและเทเลพอร์ตหากพบเงื่อนไขที่กำหนด
checkForBestNodeAndTeleport()
