-- Localizing services and engine methods for maximum Luau speed
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local floor = math.floor
local clock = os.clock

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

-- Configuration
local TARGET_FPS = 120
local SPEED_MULTIPLIER = 1.0
local CORNER_RADIUS = UDim.new(0, 16)

-- 1. Ensure frames_base64.txt exists; download it if not
local FRAMES_FILE = "frames_base64.txt"
local FRAMES_URL  = "https://raw.githubusercontent.com/chromex1/chromex/refs/heads/main/frames_base64.txt"

if not isfile(FRAMES_FILE) then
    print("[Volt] frames_base64.txt not found — downloading...")

    local ok, result = pcall(function()
        -- Fetch raw content and write it to workspace
        local data = game:HttpGet(FRAMES_URL, true)
        writefile(FRAMES_FILE, data)
    end)

    if not ok then
        error("[Volt] Failed to download frames_base64.txt: " .. tostring(result))
    end

    print("[Volt] Download complete.")
end

-- 2. Read base64 frames from workspace
local success, fileData = pcall(function()
    return readfile(FRAMES_FILE)
end)

if not success or not fileData then
    error("[Volt] Could not read frames_base64.txt after download attempt!")
end

local b64Frames = HttpService:JSONDecode(fileData)
local totalFrames = #b64Frames
local assetIds = table.create(totalFrames)

-- 3. Check cache or write files instantly
for i = 1, totalFrames do
    local fileName = "vid_120fps_frame_" .. i .. ".png"
    local exists = isfile and isfile(fileName) or pcall(function() return readfile(fileName) end)
    
    if not exists then
        local rawBytes = crypt.base64decode(b64Frames[i])
        writefile(fileName, rawBytes)
    end
    assetIds[i] = getcustomasset(fileName)
end

-- 4. Create the UI but keep it completely disabled
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "VoltMovableVideo"
screenGui.ResetOnSpawn = false
screenGui.Enabled = false
screenGui.Parent = playerGui

local videoContainer = Instance.new("Frame")
videoContainer.Size = UDim2.new(0, 480, 0, 270)
videoContainer.Position = UDim2.new(0.5, -240, 0.5, -135)
videoContainer.BackgroundTransparency = 1
videoContainer.BorderSizePixel = 0
videoContainer.Parent = screenGui

local imgA = Instance.new("ImageLabel")
imgA.Size = UDim2.new(1, 0, 1, 0)
imgA.Position = UDim2.new(0, 0, 0, 0)
imgA.BackgroundTransparency = 1
imgA.BorderSizePixel = 0
imgA.ZIndex = 2
imgA.Parent = videoContainer

local uiCornerA = Instance.new("UICorner")
uiCornerA.CornerRadius = CORNER_RADIUS
uiCornerA.Parent = imgA

local imgB = imgA:Clone()
imgB.ZIndex = 1
imgB.Parent = videoContainer

imgA.Image = assetIds[1]
imgB.Image = assetIds[2]

-- 5. Synchronous Loading & Pre-Priming
print("[Volt] Initializing memory stream...")

pcall(function()
    ContentProvider:PreloadAsync(assetIds)
end)

pcall(function()
    ContentProvider:PreloadAsync({imgA, imgB})
end)

RunService.RenderStepped:Wait()

screenGui.Enabled = true
print("[Volt] Pre-priming complete! Playback starting smoothly.")

-- 6. Drag-and-Drop Handler
local dragging = false
local dragInput, dragStart, startPos

local function updateDrag(input)
    local delta = input.Position - dragStart
    videoContainer.Position = UDim2.new(
        startPos.X.Scale, startPos.X.Offset + delta.X,
        startPos.Y.Scale, startPos.Y.Offset + delta.Y
    )
end

local function hookDragInputs(element)
    element.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = videoContainer.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    element.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
end

hookDragInputs(imgA)
hookDragInputs(imgB)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        updateDrag(input)
    end
end)

-- 7. High-Performance Playback Loop
local lastUpdate = clock()
local frameAccumulator = 1
local lastFrame = 1
local playbackConnection

local function fadeOutAndDestroy()
    playbackConnection:Disconnect()

    local fadeInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local tweenA = TweenService:Create(imgA, fadeInfo, {ImageTransparency = 1})
    local tweenB = TweenService:Create(imgB, fadeInfo, {ImageTransparency = 1})

    tweenA:Play()
    tweenB:Play()

    tweenA.Completed:Connect(function()
        screenGui:Destroy()
    end)
end

playbackConnection = RunService.RenderStepped:Connect(function()
    local now = clock()
    local dt = now - lastUpdate
    lastUpdate = now

    local framesToAdvance = dt * TARGET_FPS * SPEED_MULTIPLIER
    frameAccumulator = frameAccumulator + framesToAdvance

    local currentFrame = floor(frameAccumulator)

    if currentFrame >= totalFrames then
        fadeOutAndDestroy()
        return
    end

    if currentFrame ~= lastFrame then
        lastFrame = currentFrame

        local nextFrame = floor(frameAccumulator + framesToAdvance)
        if nextFrame > totalFrames then nextFrame = totalFrames end

        if imgA.ZIndex == 2 then
            imgA.ZIndex = 1
            imgB.ZIndex = 2
            imgA.Image = assetIds[nextFrame]
        else
            imgB.ZIndex = 1
            imgA.ZIndex = 2
            imgB.Image = assetIds[nextFrame]
        end
    end
end)
