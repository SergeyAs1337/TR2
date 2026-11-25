-- StarterPlayer/StarterPlayerScripts/EventBanner  (LocalScript)  v2 — стиль админ-панели
-- Заменяет StarterGui/EventUI (его нужно удалить, иначе баннер покажется дважды).
-- Слушает ReplicatedStorage.EventAnnouncement, как и старый EventLabel:
--   * название события -> тёмная плашка с оранжевой полоской и подписью «СОБЫТИЕ»;
--   * объявление админа (текст начинается с «📢») -> синяя полоска и подпись «ОБЪЯВЛЕНИЕ»;
--   * не-строки (nil при остановке события) игнорируются, новое объявление заменяет текущее.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UILib = require(ReplicatedStorage:WaitForChild("UILib"))
local THEME = UILib.THEME

local SHOW_TIME = 5 -- секунд на экране
local HIDDEN_Y = -120
local SHOWN_Y = 16
local ANNOUNCE_PREFIX = "📢"

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("EventAnnouncement")

local gui = UILib.screenGui("EventBanner", 15, player)

local banner = UILib.panel(gui, {
	Name = "Banner",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, HIDDEN_Y),
	Size = UDim2.new(0, 520, 0, 72),
	BackgroundColor3 = THEME.background,
	BackgroundTransparency = 0.05,
	Visible = false,
})
UILib.fitScale(banner)
UILib.stroke(banner, 1, THEME.border)

local strip = UILib.make("Frame", { -- цветная полоска слева: событие / объявление
	Name = "Strip",
	Position = UDim2.new(0, 10, 0, 10),
	Size = UDim2.new(0, 4, 1, -20),
	BackgroundColor3 = UILib.palette("warn").face,
	BorderSizePixel = 0,
}, banner)
UILib.corner(strip, 2)

local tagLabel = UILib.text(banner, "", {
	Name = "Tag",
	Position = UDim2.new(0, 26, 0, 10),
	Size = UDim2.new(1, -40, 0, 16),
	TextSize = 12,
	TextColor3 = UILib.palette("warn").hover,
	TextXAlignment = Enum.TextXAlignment.Left,
})

local nameLabel = UILib.text(banner, "", {
	Name = "EventName",
	Position = UDim2.new(0, 26, 0, 28),
	Size = UDim2.new(1, -40, 0, 34),
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
})
UILib.make("UITextSizeConstraint", { MaxTextSize = 24, MinTextSize = 12 }, nameLabel)

local STYLES = {
	event = { tag = "СОБЫТИЕ", color = "warn" },
	announce = { tag = "ОБЪЯВЛЕНИЕ", color = "accent" },
}

local function applyStyle(style)
	local colors = UILib.palette(style.color)
	tagLabel.Text = style.tag
	tagLabel.TextColor3 = colors.hover
	strip.BackgroundColor3 = colors.face
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
	UILib.tween(banner, 0.35, { Position = UDim2.new(0.5, 0, 0, SHOWN_Y) })

	task.wait(SHOW_TIME)
	if myGeneration ~= generation then
		return
	end

	UILib.tween(banner, 0.35, { Position = UDim2.new(0.5, 0, 0, HIDDEN_Y) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.wait(0.36)
	if myGeneration ~= generation then
		return
	end
	banner.Visible = false
end)
