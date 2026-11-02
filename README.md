# Meowthjr's legit menu (Pistol Duels)

A local-only cosmetic menu for the Roblox game **Pistol Duels**. Everything it changes is on your own screen only:
other players, your inventory, trades and purchases are never touched.

Made by meowthjr & Claude.

## Features

- **Skins:** put any Glock, Tec-9, Deagle or Knife skin on your own weapon, with pattern and wear for patterned skins.
  Favorites (★), three loadout slots, and a shuffle mode that rolls a random skin each time you equip.
- **3D preview:** a turning preview of the skin under your mouse.
- **Tint:** recolors a skin's own texture (blue on Emerald comes out blue-green). Each weapon has its own tint.
- **Ammo FX:** give each weapon any ammo FX (Reaper, Blaze, Static, Phantom, Frostbite, Tide, Rift, Starfall, Gale,
  Eclipse, Prism, or the Bloxxed kill effect): your tracer, sparks, muzzle flash, impacts, shot sound and kill effect
  change with it. Only you see it.
- **Effects:** bullet tracers on your own shots, and a spin on your own weapon model.
- **Boost:** more FPS. Lower graphics quality, FPS cap, and optionally no post effects, particles or decals, plus
  plain materials. Everything goes back when you turn it off.
- **Display:** stretched resolution, a draggable keystrokes / FPS / ping overlay, and a highlight on your own character.
- **World:** color looks, glow and sun rays. They can only darken the map, never brighten it.
- **Camera:** motion blur on fast turns, field of view, weapon size and position.
- **Settings:** rebindable hotkeys, window size, accent color.
- **Auto slide on jump** (Settings): after each jump the slide key is pressed for you just before you land, so you
  land straight into a slide. Hold jump to keep slide-jumping. Only when you're running fast enough to slide.

## How to use

1. Run `PistolDuelsSkinChanger.lua` in your executor while in Pistol Duels. It needs `setthreadidentity`, because the
   game's own modules have to be required from identity 2.
2. **RightShift** shows or hides the window. **RightCtrl** frees the cursor in first person. Both keys can be changed
   in Settings.
3. Pick a weapon on the left, then click a skin. Click it again to turn it off.

Your choices are saved to `pistol_duels_skin_changer.json` in your executor's workspace folder. Running the script
again replaces the old copy cleanly, and the × button undoes everything it changed.

## Privacy

While the script runs, it sends an anonymous ping every few minutes so the author can see how many people are using
it. The ping holds only a random id made up for that one run and the number of the server you're in (as shown in the
game's server list, with its region): no username, no device ID, and nothing from your computer.

## Note

Using executors and third-party scripts is against Roblox's Terms of Use and can get an account banned. Use at your
own risk.
