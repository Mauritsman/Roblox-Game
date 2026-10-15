-- datamodel: Server/Client
-- play: yes
-- goal: no errors or warnings from our code in the console (LogService), in both Server and Client
-- Run it in both datamodels, at the end of the suite (then the log holds everything from the whole playtest).

return T.run("90 console free of errors from our code", "Server/Client", function()
	local ours, unknown, ignored = T.logProblems()
	local function firstFew(list: { string }, n: number): string
		local out = {}
		for i = 1, math.min(n, #list) do
			table.insert(out, (string.gsub(string.sub(list[i], 1, 220), "\n", " ")))
		end
		return table.concat(out, " || ")
	end

	T.step(
		"no errors/warnings from our scripts",
		#ours == 0,
		if #ours > 0 then `{#ours}: ` .. firstFew(ours, 5) else nil
	)
	T.step(
		"no other unknown errors",
		#unknown == 0,
		if #unknown > 0 then `{#unknown}: ` .. firstFew(unknown, 5) else nil
	)
	T.info(`{#ignored} messages from Roblox itself ignored (CorePackages/UIBlox etc.)`)

	-- Confirm our code actually started (otherwise "no errors" means nothing).
	local startedLine = nil
	for _, entry in T.Log:GetLogHistory() do
		if string.find(entry.message, "Crowbar Crew", 1, true) then
			startedLine = entry.message
		end
	end
	T.step("startup line of our code is in the log", startedLine ~= nil, startedLine)
end)
