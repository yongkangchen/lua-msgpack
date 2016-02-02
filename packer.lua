local m = {}
local char = string.char
local floor = math.floor
m['nil'] = function(s)
	s(0xc0)
end

m['boolean'] = function(s, v)
	if v then
		s(0xc3)
	else
		s(0xc2)
	end
end

local function int( n )
	if n >= 0 then
		if n <= 0x7F then --positive fixint
			return n
		elseif n <= 0xFF then --uint 8
			return 0xCC, n
		elseif n <= 0xFFFF then --uint 16
			return 0xCD, floor(n / 0x100), n % 0x100
		elseif n <= 0xFFFFFFFF then
			return 0xCE,      -- uint32
					floor(n / 0x1000000),
					floor(n / 0x10000) % 0x100,
					floor(n / 0x100) % 0x100,
					n % 0x100
		else
            return 0xCF,      -- uint64
					0,         -- only 53 bits from double
					floor(n / 0x1000000000000) % 0x100,
					floor(n / 0x10000000000) % 0x100,
					floor(n / 0x100000000) % 0x100,
					floor(n / 0x1000000) % 0x100,
					floor(n / 0x10000) % 0x100,
					floor(n / 0x100) % 0x100,
					n % 0x100
		end
	else
		if n >= -0x20 then
            return 0xE0 + 0x20 + n   -- fixnum_neg
        elseif n >= -0x80 then
            return 0xD0, 0x100 + n -- int8
        elseif n >= -0x8000 then
            n = 0x10000 + n
            return 0xD1, floor(n / 0x100), n % 0x100 -- int16
        elseif n >= -0x80000000 then
            n = 0x100000000 + n
            return 0xD2,      -- int32
					floor(n / 0x1000000),
					floor(n / 0x10000) % 0x100,
					floor(n / 0x100) % 0x100,
					n % 0x100
        else
            return 0xD3,      -- int64
					0xFF,      -- only 53 bits from double
					floor(n / 0x1000000000000) % 0x100,
					floor(n / 0x10000000000) % 0x100,
					floor(n / 0x100000000) % 0x100,
					floor(n / 0x1000000) % 0x100,
					floor(n / 0x10000) % 0x100,
					floor(n / 0x100) % 0x100,
					n % 0x100
        end
	end
end

m['number'] = function(s, n)
	s(int(floor(n)))
end

local function str_head(n)
	if n <= 0x1F then
		return 0xA0 + n -- fixstr
	elseif n < 0xFF then
		return 0xD9, n --str8
	elseif n <= 0xFFFF then
		return 0xDA, floor(n / 0x100), n % 0x100 --str16
	else
		error "overflow in pack string"
	end
end

m['string'] = function(s, str)
	s(str_head(#str))
	s(str)
end

local function map(s, tbl, n)
	if n <= 0x0F then
		s(0x80+n) -- fixmap
	elseif n <= 0xFF then --map8
		s(0xD7, n)
	elseif n <= 0xFFFF then
		s(0xDE, floor(n / 0x100), n % 0x100) -- map16
	else
		error "overflow in pack map"
	end

	for k,v in pairs(tbl) do
		m[type(k)](s, k)
		m[type(v)](s, v)
	end
end

local function array(s, tbl, n)
	if n <= 0x0F then
        s(0x90 + n)      -- fixarray
    elseif n <= 0xFF then
    	s(0xD8, n) --array8
    elseif n <= 0xFFFF then
        s(0xDC, floor(n / 0x100), n % 0x100) -- array16
    else
        error "overflow in pack array"
    end

    for i = 1, n do
        local v = tbl[i]
        m[type(v)](s, v)
    end
end

m['table'] = function(s, tbl)
	local is_map, n, max = false, 0, 0
	for k in pairs(tbl) do
		if type(k) == 'number' and k > 0 then
			if k > max then
				max = k
			else
				is_map = true
			end
		else
			is_map = true
		end
		n = n + 1
	end

	if max ~= n then
		is_map = true
	end

	if is_map then
		map(s, tbl, n)
	else
		array(s, tbl, n)
	end
end

function m.write( data )
	local buf = {}
	local function writer( ... )
		local n = select("#",...)
		if n == 1 then
			local v = select(1, ...)
			if type(v) == "string" then
				table.insert(buf, v)
			else
				table.insert(buf, char(v))
			end
		else
			table.insert(buf, char(...))
		end
	end
	m[type(data)](writer, data)
	return table.concat(buf)
end

return m
