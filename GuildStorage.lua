GDKPCredit=GDKPCredit or {}
local A=GDKPCredit
-- The account identity is shared across characters; all ledger state is guild scoped.
function A:ActivateGuildLedger()
  local root=GDKPCreditDB
  if not root or not self.TrackingGuildKey then return false end
  local guildKey=self:TrackingGuildKey()
  local key=guildKey or "__no_guild__"
  if self.activeLedgerKey==key then return false end
  root.guildLedgers=root.guildLedgers or {}
  local ledger=root.guildLedgers[key]
  if not ledger then
    if guildKey and not root.legacyLedgerGuild then
      ledger={}
      for field,value in pairs(root) do
        if field~="guildLedgers" and field~="localAccount" and field~="legacyLedgerGuild" then ledger[field]=self.DeepCopy(value) end
      end
      root.legacyLedgerGuild=key
    else
      ledger={initialized=true,version=1,players={},characterMap={},history={},raids={},treasury=0,reserve=0,settings={}}
    end
    root.guildLedgers[key]=ledger
  end
  root.localAccount=root.localAccount or (self.db and self.db.localAccount)
  ledger.localAccount=root.localAccount
  self.db=ledger; self.activeLedgerKey=key
  self.strictGuildSnapshots=true
  self.singleLedgerWriter=true
  return true
end
