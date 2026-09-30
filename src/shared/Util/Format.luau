--!strict
-- Number formatting for UI. Pure.

local Format = {}

-- 1234567 -> "1,234,567"
function Format.commas(n: number): string
	local negative = n < 0
	local s = tostring(math.floor(math.abs(n)))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return (if negative then "-" else "") .. out
end

local SUFFIXES = { "K", "M", "B", "T", "Qa", "Qi" }

-- Full digits below 100K, then 123.4K / 1.5M style.
function Format.cash(n: number): string
	local abs = math.abs(n)
	if abs < 100000 then
		return "$" .. Format.commas(n)
	end
	local index = 0
	while abs >= 1000 and index < #SUFFIXES do
		abs /= 1000
		index += 1
	end
	local text = if abs >= 100
		then string.format("%d", math.floor(abs))
		else string.format("%.1f", math.floor(abs * 10) / 10)
	text = text:gsub("%.0$", "")
	return (if n < 0 then "-$" else "$") .. text .. SUFFIXES[index]
end

return Format
