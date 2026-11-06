-- Game windows. Managed by ~/.dotfiles modules/omarchy.
-- Proton/Wine games (steam_app_*) ask to be activated again whenever they lose focus. With Omarchy's
-- focus_on_activate that pulls focus (and the cursor) straight back from any window floating over the game, such
-- as the Battle.net launcher. Same fix Omarchy uses for Telegram (apps/telegram.lua). The launcher's own windows
-- (Battle.net, Battle.net Login, ...) keep activation so the tray and `Battle.net.exe --exec` can still raise them.
o.window({ class = "^steam_app_.*$", title = "negative:^Battle\\.net.*" }, { focus_on_activate = false })

-- Omarchy floats the Battle.net launcher (apps/battlenet.lua). A floating window stacks above every tiled one, so on
-- the HP's monocle screen it covered each summoned app. As a normal window cells gives it a cell on the 4K and it
-- joins the monocle stack on the HP. Our rules load after Omarchy's, so this float = false wins.
o.window({ class = "^steam_app_battlenet$", title = "^Battle\\.net$" }, { float = false })
