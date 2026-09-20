local BitSetInfinity = {}
BitSetInfinity.__index = BitSetInfinity
BitSetInfinity.__metatable = "BitSetInfinity" -- Hands off my metatable

-- I don't care anymore if you're doing arithmetic computation with a bitset you're using it wrong
--[[function BitSetInfinity.__add(a, b) -- ADD (+)
	a:EqualiseLength(b)
	local set = {}
	local carry = 0
	for i = 1, #a do
		print(a[i], b[i], carry)
		set[i] = (a[i] + b[i] + carry) % 64
		carry = (a[i] + b[i]) // 64
		print(set[i], carry)
	end

	if carry > 0 then
		set[#set + 1] = carry
	end

	return BitSetInfinity(table.unpack(set))
end]]

function BitSetInfinity.__band(a, b) -- Bitwise AND (&)
	a, b = a:Clone(), b:Clone()
	a:EqualiseLength(b)
	local set = {}
	for i = 1, #a do
		set[i] = a[i] & b[i]
	end

	return BitSetInfinity(table.unpack(set))
end

function BitSetInfinity.__bor(a, b) -- Bitwise OR (|)
	a, b = a:Clone(), b:Clone()
	a:EqualiseLength(b)
	local set = {}
	for i = 1, #a do
		set[i] = a[i] | b[i]
	end

	return BitSetInfinity(table.unpack(set))
end

function BitSetInfinity.__bxor(a, b) -- Bitwise XOR (~)
	a, b = a:Clone(), b:Clone()
	a:EqualiseLength(b)
	local set = {}
	for i = 1, #a do
		set[i] = a[i] ~ b[i]
	end

	return BitSetInfinity(table.unpack(set))
end

function BitSetInfinity.__bnot(a) -- Bitwise NOT (~)
	a = a:Clone()
	local set = {}
	for i = 1, #a do
		set[i] = ~a[i]
	end

	local newSet = BitSetInfinity(table.unpack(set))
	newSet.Inverted = not a.Inverted

	return newSet
end

function BitSetInfinity.__eq(a, b) -- Equality (==)
	a, b = a:Clone(), b:Clone()
	a:EqualiseLength(b)
	local equal = true
	for i = 1, #a do
		equal = equal and a[i] == b[i]
	end

	return equal
end

function BitSetInfinity.__lt(a, b) -- Less Than (<)
	a, b = a:Clone(), b:Clone()
	a:EqualiseLength(b)
	for i = #a, 1, -1 do
		if a[i] ~= b[i] then
			return a[i] < b[i]
		end
	end

	return false
end

function BitSetInfinity.__le(a, b) -- Less Equal (<=)
	a, b = a:Clone(), b:Clone()
	a:EqualiseLength(b)
	local equal = true

	for i = #a, 1, -1 do
		equal = equal and a[i] == b[i]

		if a[i] ~= b[i] then
			return a[i] < b[i]
		end
	end

	return equal
end

function BitSetInfinity.__tostring(set) -- Stringify
	local suff = ""
	for i = 1, #set do
		suff = suff .. set[i]
		if i ~= #set then suff = suff .. "." end
	end

	return "BitSetInfinity: " .. suff -- This isn't how BitSet128 prints stuff but also sucks to suck
end

function BitSetInfinity:__newindex(key, value)
	if type(key) == "number" then
		while #self < key do
			self:Extend()
		end

		self[key] = value
	end
end

function BitSetInfinity:Clone()
	local set = {}
	for i = 1, #self do set[i] = self[i] end
	local new = BitSetInfinity(table.unpack(set))
	new.Inverted = self.Inverted

	return new
end

function BitSetInfinity:Extend(value)
	rawset(self, #self + 1, value or (self.Inverted and -1 or 0))
end

function BitSetInfinity:Extended(value)
	local new = self:Clone()
	new:Extend(value)
	return new
end

function BitSetInfinity:Trim()
	local check = self.Inverted and -1 or 0
	while self[#self] == check do
		self[#self] = nil
	end
end

function BitSetInfinity:Trimmed()
	local new = self:Clone()
	new:Trim()
	return new
end

function BitSetInfinity:EqualiseLength(comparator)
	if #self < #comparator then
		for i = #self + 1, #comparator do
			self:Extend()
		end
	elseif #comparator < #self then
		comparator:EqualiseLength(self)
	end
end

function BitSetInfinity:CountFlags()
	local n = 0
	for _, set in pairs(self:Clone()) do
		while set ~= 0 do
			n = n + 1
			set = set & set - 1
		end
	end

	return n
end

function BitSetInfinity:HasFlags(mask)
	return self & mask == mask
end

function BitSetInfinity:HasAnyFlag(mask)
	return self & mask ~= BitSetInfinity.Zero
end

function BitSetInfinity:ForEach(toCall) -- This is kinda out there lmao, runs the function `toCall` for each "on" bit, passing said bit as an arg for the function
	for i, set in pairs(self:Clone()) do
		while set ~= 0 do
			local temp = set
			set = set & set - 1

			local dummy = BitSetInfinity(0)
			dummy[i] = temp &~ set
			toCall(dummy)
		end
	end
end

function BitSetInfinity:GetFirstIndex()
	for i = 1, #self do
		if self[i] ~= 0 then
			for j = 0, 63 do
				if self[i] & 1 << j == 1 << j then
					return (i - 1) * 64 + j
				end 
			end
		end
	end
end

function BitSetInfinity.FromIndex(index) -- Intended constructor
	local set = {}

	for i = 1, index // 64 + 1 do
		table.insert(set, 0)
	end

	set[#set] = 1 << (index % 64)
	return BitSetInfinity(table.unpack(set))
end

function BitSetInfinity.IsBitSetInfinity(value) -- Static function for detemining the BitSetInfinity-ness of an arbitrary value
	return getmetatable(value) == "BitSetInfinity"
end

setmetatable(BitSetInfinity, {
	__call = function(_, ...)
		return setmetatable({...}, BitSetInfinity)
	end,
})

rawset(BitSetInfinity, "Zero", BitSetInfinity(0))
rawset(BitSetInfinity, "One", ~BitSetInfinity.Zero)
TearFlagsLib.BitSetInfinity = BitSetInfinity

function TearFlagsLib.UpdateBitSetInfinity(setList) -- Outdated bitsets need their metatable replaced
	for key, set in pairs(setList) do
		if BitSetInfinity.IsBitSetInfinity(set) then
			setList[key] = BitSetInfinity(table.unpack(set))
		end
	end
end