local players = game:GetService("Players")
local coreGui = game:GetService("CoreGui")
local soundService = game:GetService("SoundService")
local lighting = game:GetService("Lighting")
local localPlayer = players.LocalPlayer

local imageUrl = "https://raw.githubusercontent.com/chromex1/chromex/blob/main/mateymate.png?raw=true"
local audio1Url = "https://raw.githubusercontent.com/chromex1/chromex/blob/main/matey%20sucking%20balls.mp3?raw=true"
local audio2Url = "https://raw.githubusercontent.com/chromex1/chromex/blob/main/idekbro.mp3?raw=true"

local folderName = "AprilFoolsAssets"
makefolder(folderName)

local imgPath = folderName .. "/mateymate.png"
local aud1Path = folderName .. "/mateysucking.mp3"
local aud2Path = folderName .. "/idekbro.mp3"

local reqFunc = request or http_request or (syn and syn.request) or (fluxus and fluxus.request)
assert(reqFunc, "No request function found.")

local function downloadAsset(url, path)
    if isfile(path) then return true end
    local res = reqFunc({Url = url, Method = "GET", Headers = {["User-Agent"] = "Mozilla/5.0"}})
    if res.StatusCode == 200 then
        writefile(path, res.Body)
        return true
    end
    return false
end

downloadAsset(imageUrl, imgPath)
downloadAsset(audio1Url, aud1Path)
downloadAsset(audio2Url, aud2Path)

local imgContent = getcustomasset(imgPath, true)
local aud1Content = getcustomasset(aud1Path, true)
local aud2Content = getcustomasset(aud2Path, true)

local faces = Enum.NormalId:GetEnumItems()

local function processInstance(obj)
    if obj:IsA("BasePart") then
        if not obj:GetAttribute("AF_Decal") and obj.Transparency < 1 then
            local size = obj.Size
            if size.X > 0.2 or size.Y > 0.2 or size.Z > 0.2 then
                obj:SetAttribute("AF_Decal", true)
                for _, face in ipairs(faces) do
                    local dec = Instance.new("Decal")
                    dec.Texture = imgContent
                    dec.Face = face
                    dec.Parent = obj
                end
            end
        end
    elseif obj:IsA("Decal") or obj:IsA("Texture") then
        pcall(function() obj.Texture = imgContent end)
    elseif obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
        pcall(function() obj.Image = imgContent end)
    elseif obj:IsA("SurfaceAppearance") then
        pcall(function()
            obj.ColorMap = imgContent
            obj.MetalnessMap = imgContent
            obj.NormalMap = imgContent
            obj.RoughnessMap = imgContent
        end)
    elseif obj:IsA("Sky") then
        pcall(function()
            obj.SkyboxBk = imgContent
            obj.SkyboxDn = imgContent
            obj.SkyboxFt = imgContent
            obj.SkyboxLf = imgContent
            obj.SkyboxRt = imgContent
            obj.SkyboxUp = imgContent
        end)
    end
end

local function deepScan(parent)
    if not parent then return end
    local descendants = parent:GetDescendants()
    for i = 1, #descendants do
        processInstance(descendants[i])
        if i % 200 == 0 then task.wait() end
    end
end

local function scanEverything()
    local services = {
        game:GetService("Workspace"),
        lighting,
        game:GetService("ReplicatedStorage"),
        game:GetService("ReplicatedFirst"),
        game:GetService("StarterGui"),
        game:GetService("StarterPlayer"),
        game:GetService("StarterPack"),
        game:GetService("Teams"),
        soundService,
        coreGui,
        players,
    }
    
    for i = 1, #services do
        deepScan(services[i])
    end
    
    for _, plr in ipairs(players:GetPlayers()) do
        pcall(function()
            if plr:FindFirstChild("PlayerGui") then deepScan(plr.PlayerGui) end
            if plr:FindFirstChild("Backpack") then deepScan(plr.Backpack) end
            if plr.Character then deepScan(plr.Character) end
        end)
    end
    
    local sky = lighting:FindFirstChildOfClass("Sky")
    if not sky then
        sky = Instance.new("Sky")
        sky.Parent = lighting
    end
    processInstance(sky)
end

scanEverything()

local function hookDescendantAdded(svc)
    pcall(function()
        svc.DescendantAdded:Connect(processInstance)
    end)
end

hookDescendantAdded(game:GetService("Workspace"))
hookDescendantAdded(lighting)
hookDescendantAdded(game:GetService("ReplicatedStorage"))
hookDescendantAdded(game:GetService("ReplicatedFirst"))
hookDescendantAdded(game:GetService("StarterGui"))
hookDescendantAdded(game:GetService("StarterPlayer"))
hookDescendantAdded(game:GetService("StarterPack"))
hookDescendantAdded(game:GetService("Teams"))
hookDescendantAdded(soundService)
hookDescendantAdded(coreGui)
hookDescendantAdded(players)

local function hookPlayer(plr)
    pcall(function()
        plr.DescendantAdded:Connect(processInstance)
        plr.CharacterAdded:Connect(function(char)
            deepScan(char)
            char.DescendantAdded:Connect(processInstance)
        end)
    end)
end

for _, plr in ipairs(players:GetPlayers()) do hookPlayer(plr) end
players.PlayerAdded:Connect(hookPlayer)

local function attachParticles(character)
    pcall(function()
        local hrp = character:WaitForChild("HumanoidRootPart", 5)
        if hrp and not hrp:FindFirstChild("AF_Particles") then
            local emitter = Instance.new("ParticleEmitter")
            emitter.Name = "AF_Particles"
            emitter.Texture = imgContent
            emitter.Rate = 300
            emitter.Lifetime = NumberRange.new(2, 4)
            emitter.Speed = NumberRange.new(8, 16)
            emitter.SpreadAngle = Vector2.new(180, 180)
            emitter.Parent = hrp
        end
    end)
end

if localPlayer.Character then
    attachParticles(localPlayer.Character)
end
localPlayer.CharacterAdded:Connect(attachParticles)

local function playSuckingSound(pitch)
    local s = Instance.new("Sound")
    s.SoundId = aud1Content
    s.Looped = true
    s.Volume = 10
    s.PlaybackSpeed = pitch
    s.Parent = soundService
    pcall(function() s:Play() end)
    s.Ended:Connect(function() pcall(function() s:Play() end) end)
    s.Stopped:Connect(function() task.wait(0.1) pcall(function() s:Play() end) end)
end

playSuckingSound(math.random(50, 200) / 100)
playSuckingSound(math.random(50, 200) / 100)

task.spawn(function()
    while true do
        local clap = Instance.new("Sound")
        clap.SoundId = aud2Content
        clap.Looped = false
        clap.Volume = 1.0
        clap.Parent = soundService
        pcall(function() clap:Play() end)
        clap.Ended:Connect(function() clap:Destroy() end)
        task.wait(10)
    end
end)
