--!strict
-- Character styles (StyleService / StyleShopController). Bought in the lobby with coins earned by
-- playing (escape +ESCAPE_REWARD, otherwise +PLAY_REWARD). Perks are applied in the match.
export type StyleDef = {
	id: string,
	displayName: string,
	price: number,
	icon: string,
	th: string, -- shop description (Thai)
	en: string,
	speedMult: number?, -- match walk speed x
	doubleJump: boolean?,
	damageTakenMult: number?, -- damage x (0.75 = 25 % less)
	noCarrySlow: boolean?, -- carrying never slows you
}

local STYLES: { [string]: StyleDef } = {
	Ninja = {
		id = "Ninja",
		displayName = "Ninja Hamster",
		price = 100,
		icon = "⚡",
		th = "ว่องไว! วิ่งเร็วขึ้น 15% และกระโดดสองชั้นได้ (กดกระโดดอีกครั้งกลางอากาศ)",
		en = "+15% speed · double jump",
		speedMult = 1.15,
		doubleJump = true,
	},
	Gym = {
		id = "Gym",
		displayName = "Gym Hamster",
		price = 100,
		icon = "💪",
		th = "แข็งแรง! ถือของหนักไม่ช้าลง และโดนดาเมจน้อยลง 25%",
		en = "Carry without slowing down · -25% damage",
		damageTakenMult = 0.75,
		noCarrySlow = true,
	},
}

for _, s in STYLES do
	table.freeze(s)
end

return table.freeze({
	ENABLED = true, -- switch: false = no shop, no perks, no coins (game as before)
	ORDER = table.freeze({ "Ninja", "Gym" }),
	STYLES = table.freeze(STYLES),
	START_COINS = 100, -- first visit: enough for one style (demo / judges can try it at once)
	ESCAPE_REWARD = 50,
	PLAY_REWARD = 10,
	DATASTORE = "WRIT_Styles_v1",
})
