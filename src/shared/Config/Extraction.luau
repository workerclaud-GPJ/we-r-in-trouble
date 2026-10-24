--!strict
-- Extraction tunables (GDD §5.8, §8.6.1, §9). ETA lives in MissionDef.exitArrivalDelay.
return table.freeze({
	DEPARTURE_COUNTDOWN = 10,
	LAST_CALL_AFTER = 45,
	LAST_CALL_QUORUM = 0.5, -- of activeCount, rounded up, min 1
	CARRIER_DESCEND_TIME = 3,
	CARRIER_DESCEND_HEIGHT = 60,
	EXIT_UNLOCK_FORCES_CRITICAL = true,
})
