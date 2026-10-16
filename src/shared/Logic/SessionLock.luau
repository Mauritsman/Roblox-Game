--!strict
-- Session lock transforms for UpdateAsync (ProfileStore's proven algorithm, as pure functions).
-- Returning nil from a transform cancels the write. Never yields.
--
-- Stored record: { data, lock = {session, job, place, at}?, savedAt, saveCount, steals }
--   load:    no record → create with my lock; lock empty/mine/stale → take; fresh foreign lock → cancel ("busy"),
--            unless `steal` (after N attempts) → take it and count the steal; newer data version → cancel.
--   save:    writes only while the lock is still mine; otherwise cancels ("lost") so two servers never both write.
--   release: a save that clears the lock.

local SessionLock = {}

export type Lock = { session: string, job: string, place: number, at: number }
export type Record = { data: any, lock: Lock?, savedAt: number, saveCount: number, steals: number }

export type LoadContext = {
	session: string,
	job: string,
	place: number,
	now: number,
	staleSeconds: number,
	steal: boolean,
	currentVersion: number,
	makeDefaults: () -> any,
	resetCorrupt: boolean?, -- the caller backed up a corrupt value; replace it with defaults
}

export type LoadOutcome = "created" | "taken" | "stale" | "stolen" | "busy" | "newer" | "corrupt" | "reset"

export type SaveContext = {
	session: string,
	now: number,
	data: any?, -- nil = keep the stored data (e.g. releasing a profile we must not overwrite)
	release: boolean,
}

export type SaveOutcome = "saved" | "released" | "lost" | "missing"

function SessionLock.isRecord(raw: any): boolean
	return type(raw) == "table" and type(raw.data) == "table"
end

local function copyRecord(raw: any): Record
	return {
		data = raw.data,
		lock = raw.lock,
		savedAt = if type(raw.savedAt) == "number" then raw.savedAt else 0,
		saveCount = if type(raw.saveCount) == "number" then raw.saveCount else 0,
		steals = if type(raw.steals) == "number" then raw.steals else 0,
	}
end

local function myLock(ctx: LoadContext): Lock
	return { session = ctx.session, job = ctx.job, place = ctx.place, at = ctx.now }
end

function SessionLock.load(raw: any, ctx: LoadContext): (Record?, LoadOutcome)
	if raw == nil then
		return { data = ctx.makeDefaults(), lock = myLock(ctx), savedAt = ctx.now, saveCount = 0, steals = 0 },
			"created"
	end
	if not SessionLock.isRecord(raw) then
		if ctx.resetCorrupt then
			return {
				data = ctx.makeDefaults(),
				lock = myLock(ctx),
				savedAt = ctx.now,
				saveCount = 0,
				steals = 0,
			},
				"reset"
		end
		return nil, "corrupt"
	end
	local version = raw.data.version
	if type(version) == "number" and version > ctx.currentVersion then
		return nil, "newer"
	end
	local record = copyRecord(raw)
	local lock = raw.lock
	local outcome: LoadOutcome
	if type(lock) ~= "table" or lock.session == ctx.session then
		outcome = "taken"
	elseif type(lock.at) ~= "number" or ctx.now - lock.at > ctx.staleSeconds then
		outcome = "stale"
	elseif ctx.steal then
		outcome = "stolen"
		record.steals += 1
	else
		return nil, "busy"
	end
	record.lock = myLock(ctx)
	return record, outcome
end

function SessionLock.save(raw: any, ctx: SaveContext): (Record?, SaveOutcome)
	if not SessionLock.isRecord(raw) then
		return nil, "missing"
	end
	local lock = raw.lock
	if type(lock) ~= "table" or lock.session ~= ctx.session then
		return nil, "lost"
	end
	local record = copyRecord(raw)
	if ctx.data ~= nil then
		record.data = ctx.data
	end
	record.savedAt = ctx.now
	record.saveCount += 1
	if ctx.release then
		record.lock = nil
		return record, "released"
	end
	record.lock = { session = lock.session, job = lock.job, place = lock.place, at = ctx.now }
	return record, "saved"
end

return SessionLock
