--!strict
-- Small UI construction kit: consistent colors, fonts, corners and strokes.

local TweenService = game:GetService("TweenService")

local Ui = {}

Ui.Colors = {
	Ink = Color3.fromRGB(45, 28, 12),
	Cream = Color3.fromRGB(255, 247, 228),
	Gold = Color3.fromRGB(255, 201, 51),
	Orange = Color3.fromRGB(255, 150, 40),
	Green = Color3.fromRGB(76, 214, 96),
	Red = Color3.fromRGB(255, 76, 76),
	Blue = Color3.fromRGB(92, 200, 255),
	Purple = Color3.fromRGB(180, 92, 255),
	Grey = Color3.fromRGB(150, 150, 150),
	White = Color3.new(1, 1, 1),
	Dark = Color3.fromRGB(35, 30, 40),
}

Ui.Font = Enum.Font.FredokaOne
Ui.TitleFont = Enum.Font.LuckiestGuy

-- Creates an instance with properties and children. `Parent` is applied last.
function Ui.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function Ui.corner(radius: UDim?): UICorner
	return Ui.new("UICorner", { CornerRadius = radius or UDim.new(0, 14) })
end

function Ui.stroke(thickness: number?, color: Color3?): UIStroke
	return Ui.new("UIStroke", {
		Thickness = thickness or 3,
		Color = color or Ui.Colors.Ink,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Ui.textStroke(thickness: number?, color: Color3?): UIStroke
	return Ui.new("UIStroke", { Thickness = thickness or 2.5, Color = color or Ui.Colors.Ink })
end

-- A label with the game's cartoon style (outlined text, scaled to fit).
function Ui.label(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		Font = Ui.Font,
		TextColor3 = Ui.Colors.White,
		TextScaled = true,
		Text = "",
	}
	for key, value in props do
		defaults[key] = value
	end
	local label = Ui.new("TextLabel", defaults)
	Ui.textStroke().Parent = label
	return label
end

function Ui.tween(
	instance: Instance,
	time: number,
	goals: { [string]: any },
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
): Tween
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		goals
	)
	tween:Play()
	return tween
end

-- Quick "pop" bounce using (or adding) a UIScale on the object.
function Ui.pop(guiObject: GuiObject, amount: number?)
	local scale = guiObject:FindFirstChildOfClass("UIScale") or Ui.new("UIScale", { Parent = guiObject })
	scale.Scale = 1 + (amount or 0.15)
	Ui.tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end

return Ui
