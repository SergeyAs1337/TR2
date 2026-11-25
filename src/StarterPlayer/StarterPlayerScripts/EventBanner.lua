-- StarterPlayer/StarterPlayerScripts/EventBanner  (LocalScript)  v1 — редизайн баннера событий
-- Заменяет StarterGui/EventUI (его нужно удалить, иначе баннер покажется дважды).
-- Слушает ReplicatedStorage.EventAnnouncement, как и старый EventLabel:
--   * название события -> жёлто-оранжевая лента с ярлыком «⚡ СОБЫТИЕ ⚡»;
--   * объявление админа (текст начинается с «📢») -> синяя лента с ярлыком «📢 ОБЪЯВЛЕНИЕ»;
--   * не-строки (nil при остановке события) игнорируются, новое объявление заменяет текущее.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UILib = require(ReplicatedStorage:WaitForChild("UILib"))
local THEME = UILib.THEME

local SHOW_TIME = 5 -- секунд на экране
local HIDDEN_Y = -170
local SHOWN_Y = 24
local ANNOUNCE_PREFIX = "📢"

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("EventAnnouncement")

local gui = UILib.screenGui("EventBanner", 15, player)

local banner = UILib.make("Frame", {
	Name = "Banner",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, HIDDEN_Y),
	Size = UDim2.new(0, 600, 0, 96),
	BackgroundTransparency = 1,
	Visible = false,
}, gui)
UILib.fitScale(banner)

local ribbon = UILib.make("Frame", {
	Name = "Ribbon",
	Position = UDim2.new(0, 0, 0, 16),
	Size = UDim2.new(1, 0, 1, -16),
	BackgroundColor3 = THEME.white,
	BorderSizePixel = 0,
}, banner)
UILib.corner(ribbon, THEME.radius + 2)
UILib.stroke(ribbon, THEME.stroke + 1)
local ribbonGradient = UILib.gradient(ribbon, UILib.palette("yellow").top, UILib.palette("orange").face)

local nameLabel = UILib.text(ribbon, "", {
	Name = "EventName",
	Position = UDim2.new(0, 16, 0, 6),
	Size = UDim2.new(1, -32, 1, -10),
	TextScaled = true,
	strokeThickness = 3,
})
UILib.make("UITextSizeConstraint", { MaxTextSize = 40, MinTextSize = 14 }, nameLabel)

local tag = UILib.make("Frame", {
	Name = "Tag",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 0),
	Size = UDim2.new(0, 220, 0, 32),
	BackgroundColor3 = THEME.white,
	BorderSizePixel = 0,
	ZIndex = 2,
}, banner)
UILib.corner(tag, 16)
UILib.stroke(tag, THEME.stroke)
local tagGradient = UILib.gradient(tag, UILib.palette("red").top, UILib.palette("red").face)
local tagLabel = UILib.text(tag, "", { Name = "Label", Size = UDim2.new(1, 0, 1, 0), TextSize = 18, ZIndex = 3 })

local STYLES = {
	event = { tag = "⚡ СОБЫТИЕ ⚡", ribbon = { "yellow", "orange" }, tagColor = "red" },
	announce = { tag = "📢 ОБЪЯВЛЕНИЕ", ribbon = { "blue", "purple" }, tagColor = "yellow" },
}

local function applyStyle(style)
	tagLabel.Text = style.tag
	ribbonGradient.Color = ColorSequence.new(UILib.palette(style.ribbon[1]).top, UILib.palette(style.ribbon[2]).face)
	local t = UILib.palette(style.tagColor)
	tagGradient.Color = ColorSequence.new(t.top, t.face)
end

local generation = 0 -- номер последнего объявления; старые обработчики сами выходят

remote.OnClientEvent:Connect(function(message)
	if typeof(message) ~= "string" or message == "" then
		return
	end

	generation += 1
	local myGeneration = generation

	local isAnnouncement = string.sub(message, 1, #ANNOUNCE_PREFIX) == ANNOUNCE_PREFIX
	if isAnnouncement then
		applyStyle(STYLES.announce)
		message = string.gsub(string.sub(message, #ANNOUNCE_PREFIX + 1), "^%s+", "")
	else
		applyStyle(STYLES.event)
	end
	nameLabel.Text = message

	banner.Visible = true
	banner.Position = UDim2.new(0.5, 0, 0, HIDDEN_Y)
	banner.Rotation = 0
	UILib.tween(banner, 0.5, { Position = UDim2.new(0.5, 0, 0, SHOWN_Y) }, Enum.EasingStyle.Back)
	task.delay(0.45, function()
		if myGeneration == generation then
			UILib.shake(banner)
		end
	end)

	task.wait(SHOW_TIME)
	if myGeneration ~= generation then
		return
	end

	UILib.tween(banner, 0.35, { Position = UDim2.new(0.5, 0, 0, HIDDEN_Y) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	task.wait(0.36)
	if myGeneration ~= generation then
		return
	end
	banner.Visible = false
end)
