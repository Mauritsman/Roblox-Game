--!nocheck
local Rng = require("../../src/shared/Logic/Rng")

return function(t)
	t.test("zelfde seed geeft zelfde reeks", function()
		local a, b = Rng.new(42), Rng.new(42)
		for _ = 1, 20 do
			t.eq(a:next(), b:next())
		end
	end)
	t.test("int blijft binnen grenzen", function()
		local r = Rng.new(7)
		for _ = 1, 500 do
			local v = r:int(3, 9)
			t.ok(v >= 3 and v <= 9, "buiten grenzen: " .. v)
		end
	end)
	t.test("shuffle houdt alle items", function()
		local r = Rng.new(1)
		local s = r:shuffle({ 1, 2, 3, 4, 5 })
		local sum = 0
		for _, v in s do
			sum += v
		end
		t.eq(#s, 5)
		t.eq(sum, 15)
	end)
end
