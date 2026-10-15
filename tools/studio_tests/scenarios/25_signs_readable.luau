-- datamodel: Client
-- play: yes
-- goal: every sign in the level (SurfaceGui text) is drawn big enough to read (read-only, no teleports)
-- Text height must fill at least 35% of its label (TextBounds measured on the client).

return T.run("25 signs are readable", "Client", function()
	local level = T.level()
	if not T.step("workspace.Level exists", level ~= nil) then
		return
	end
	local labels = {}
	for _, d in (level :: Instance):GetDescendants() do
		if d:IsA("TextLabel") and d.Parent and d.Parent:IsA("SurfaceGui") and d.Text ~= "" then
			table.insert(labels, d)
		end
	end
	T.step("signs found", #labels > 0, `{#labels} SurfaceGui text labels`)
	task.wait(0.5) -- let the client lay out the text
	for _, label in labels do
		local height = label.AbsoluteSize.Y
		local fill = if height > 0 then label.TextBounds.Y / height else 0
		local text = string.gsub(label.Text, "\n", " / ")
		T.step(
			`sign "{string.sub(text, 1, 30)}" readable`,
			fill >= 0.35,
			string.format(
				"text %.0f px high in a %.0f px label (%.0f%%), TextScaled=%s, TextSize=%d",
				label.TextBounds.Y,
				height,
				fill * 100,
				tostring(label.TextScaled),
				label.TextSize
			)
		)
	end
end)
