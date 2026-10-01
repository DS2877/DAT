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

-- A label without the outline (for dark text on light panels).
function Ui.plainLabel(props: { [string]: any }): TextLabel
	local label = Ui.label(props)
	local outline = label:FindFirstChildOfClass("UIStroke")
	if outline then
		outline:Destroy()
	end
	return label
end

-- A vertical gradient (top color, bottom color).
function Ui.gradient(top: Color3, bottom: Color3, rotation: number?): UIGradient
	return Ui.new("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = rotation or 90,
	})
end

-- Caps how big scaled text may grow (keeps rows of cards consistent).
function Ui.maxText(size: number): UITextSizeConstraint
	return Ui.new("UITextSizeConstraint", { MaxTextSize = size })
end

-- A neutral top-to-bottom shade. Use this (not a colored gradient) on text
-- buttons: a UIGradient tints the parent's text too, so colored gradients
-- would dye white button text. The color comes from BackgroundColor3.
function Ui.shade(): UIGradient
	return Ui.gradient(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 205))
end

-- Lighter / darker versions of a color.
function Ui.lighten(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(1, 1, 1), amount)
end
function Ui.darken(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

-- A chunky cartoon button: gradient fill, ink outline, outlined text.
function Ui.button(props: { [string]: any }, color: Color3): TextButton
	local defaults = {
		Font = Ui.TitleFont,
		TextScaled = true,
		TextColor3 = Ui.Colors.White,
		BackgroundColor3 = color,
		AutoButtonColor = true,
		Text = "",
	}
	for key, value in props do
		defaults[key] = value
	end
	local button = Ui.new("TextButton", defaults, {
		Ui.corner(UDim.new(0, 16)),
		Ui.stroke(4),
		Ui.textStroke(3),
		Ui.shade(),
		Ui.new("UIPadding", {
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
		}),
	})
	return button
end

-- Recolors a button made with Ui.button.
function Ui.setButtonColor(button: GuiObject, color: Color3)
	button.BackgroundColor3 = color
end

-- A small rounded tag ("Rare", "2x Cash").
function Ui.chip(text: string, color: Color3, props: { [string]: any }?): TextLabel
	local defaults: { [string]: any } = {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 28),
		BackgroundTransparency = 0,
		BackgroundColor3 = color,
		TextScaled = false,
		TextSize = 18,
		Text = text,
	}
	for key, value in props or {} do
		defaults[key] = value
	end
	local chip = Ui.label(defaults)
	Ui.corner(UDim.new(1, 0)).Parent = chip
	Ui.new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = chip })
	return chip
end

export type PanelOptions = {
	name: string,
	title: string,
	icon: string?,
	accent: Color3,
	width: number,
	height: number,
	parent: Instance,
	dim: boolean?, -- darken the screen behind (tap outside to close)
	position: UDim2?,
	anchor: Vector2?,
}

export type Panel = {
	root: Frame, -- toggle Visible on this
	card: Frame,
	header: Frame,
	title: TextLabel,
	body: Frame,
	close: TextButton,
}

-- The game's standard window: a cream card with a drop shadow, a colored
-- title ribbon with an icon, a close button, and a body frame for content.
-- It shrinks to fit short screens.
function Ui.panel(o: PanelOptions): Panel
	local root = Ui.new("Frame", {
		Name = o.name,
		AnchorPoint = o.anchor or Vector2.new(0.5, 0.5),
		Position = o.position or UDim2.fromScale(0.5, 0.54),
		Size = UDim2.new(0, o.width, 0.88, 0),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 20,
		Parent = o.parent,
	}, {
		Ui.new("UISizeConstraint", { MaxSize = Vector2.new(o.width, o.height) }),
		Ui.new("UIScale"),
	})
	Ui.new("Frame", {
		Name = "Shadow",
		Position = UDim2.fromOffset(0, 10),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.6,
		Parent = root,
	}, { Ui.corner(UDim.new(0, 28)) })
	local card = Ui.new("Frame", {
		Name = "Card",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = root,
	}, {
		Ui.corner(UDim.new(0, 28)),
		Ui.stroke(5),
		Ui.gradient(Color3.fromRGB(255, 251, 238), Color3.fromRGB(255, 238, 205)),
	})
	local header = Ui.new("Frame", {
		Name = "Header",
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.new(1, -24, 0, 62),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = card,
	}, {
		Ui.corner(UDim.new(0, 20)),
		Ui.stroke(4),
		Ui.gradient(Ui.lighten(o.accent, 0.3), Ui.darken(o.accent, 0.1)),
	})
	-- A soft shine across the top half of the ribbon.
	Ui.new("Frame", {
		Name = "Shine",
		Position = UDim2.fromOffset(10, 5),
		Size = UDim2.new(1, -20, 0.38, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.78,
		Parent = header,
	}, { Ui.corner(UDim.new(1, 0)) })
	local title = Ui.label({
		Name = "Title",
		Position = UDim2.fromOffset(18, 8),
		Size = UDim2.new(1, -90, 1, -16),
		Font = Ui.TitleFont,
		Text = if o.icon then o.icon .. "  " .. o.title else o.title,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = header,
	})
	local close = Ui.new("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(48, 48),
		BackgroundColor3 = Color3.fromRGB(240, 70, 64),
		Font = Ui.TitleFont,
		Text = "X",
		TextScaled = true,
		TextColor3 = Ui.Colors.White,
		Parent = header,
	}, {
		Ui.corner(UDim.new(1, 0)),
		Ui.stroke(3),
		Ui.textStroke(2),
		Ui.shade(),
		Ui.new("UIPadding", {
			PaddingTop = UDim.new(0, 9),
			PaddingBottom = UDim.new(0, 9),
			PaddingLeft = UDim.new(0, 9),
			PaddingRight = UDim.new(0, 9),
		}),
	})
	local body = Ui.new("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(18, 86),
		Size = UDim2.new(1, -36, 1, -100),
		BackgroundTransparency = 1,
		Parent = card,
	})
	close.Activated:Connect(function()
		root.Visible = false
	end)

	if o.dim then
		local dim = Ui.new("TextButton", {
			Name = o.name .. "Dim",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.5,
			AutoButtonColor = false,
			Text = "",
			Visible = false,
			ZIndex = 19,
			Parent = o.parent,
		})
		dim.Activated:Connect(function()
			root.Visible = false
		end)
		root:GetPropertyChangedSignal("Visible"):Connect(function()
			dim.Visible = root.Visible
		end)
	end
	root:GetPropertyChangedSignal("Visible"):Connect(function()
		if root.Visible then
			local scale = root:FindFirstChildOfClass("UIScale") :: UIScale
			scale.Scale = 0.85
			Ui.tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		end
	end)
	return { root = root, card = card, header = header, title = title, body = body, close = close }
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
