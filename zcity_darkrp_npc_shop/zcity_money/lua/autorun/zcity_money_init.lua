-- Disabled because the server uses DarkRP as the only money source.
-- This addon previously created a parallel money database and NWInt balance,
-- which conflicted with DarkRP money, trader purchases and radial actions.

if SERVER then
    print("[ZCity-Money] Disabled: using DarkRP money instead.")
end
