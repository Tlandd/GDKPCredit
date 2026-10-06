GDKPCredit = GDKPCredit or {}

-- Public builds intentionally start with an empty guild database.
-- Existing GPCDKP users are migrated automatically by Core.lua.
GDKPCredit.BOOTSTRAP = {
  version = 1,
  treasury = 0,
  reserve = 0,
  players = {},
  characterMap = {},
}

-- Common Classic world buffs. A raid member passes at 3+ tracked buffs by default.
GDKPCredit.WORLD_BUFFS = {
  [22888]="Rallying Cry of the Dragonslayer",
  [16609]="Warchief's Blessing",
  [15366]="Songflower Serenade",
  [24425]="Spirit of Zandalar",
  [22817]="Mol'dar's Moxie",
  [22818]="Slip'kik's Savvy",
  [22820]="Fengus' Ferocity",
  [23735]="Sayge's Dark Fortune of Strength",
  [23736]="Sayge's Dark Fortune of Agility",
  [23737]="Sayge's Dark Fortune of Stamina",
  [23738]="Sayge's Dark Fortune of Spirit",
  [23766]="Sayge's Dark Fortune of Intelligence",
  [23767]="Sayge's Dark Fortune of Armor",
  [23768]="Sayge's Dark Fortune of Damage",
  [23769]="Sayge's Dark Fortune of Resistance",
}

-- Common persistent raid consumes. The list is intentionally broad and editable.
-- A raid member passes at 2+ tracked consume buffs by default.
GDKPCredit.CONSUMES = {
  [17626]="Flask of the Titans",
  [17627]="Distilled Wisdom",
  [17628]="Supreme Power",
  [17629]="Chromatic Resistance",
  [17538]="Elixir of the Mongoose",
  [17539]="Greater Arcane Elixir",
  [11405]="Elixir of the Giants",
  [11390]="Arcane Elixir",
  [26276]="Elixir of Greater Firepower",
  [24363]="Mageblood Potion",
  [16323]="Juju Power",
  [16329]="Juju Might",
  [17038]="Winterfall Firewater",
  [18125]="Blessed Sunfruit Juice",
  [18141]="Blessed Sunfruit",
  [18192]="Grilled Squid",
  [18194]="Nightfin Soup",
  [18193]="Hot Smoked Bass",
  [18191]="Runn Tum Tuber Surprise",
  [22730]="Heavy Kodo Stew",
  [19710]="Well Fed",
  [24799]="Well Fed",
  [24800]="Well Fed",
  [24801]="Well Fed",
  [10667]="R.O.I.D.S.",
  [10668]="Lung Juice Cocktail",
  [10669]="Ground Scorpok Assay",
  [10670]="Cerebral Cortex Compound",
  [10671]="Gizzard Gum",
}
