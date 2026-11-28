# Meowthjr's menu (Pistol Duels)

A menu for **Pistol Duels** with local cosmetic options, aim assistance, ESP and an incognito display layer.
Cosmetic skin changes do not change inventory ownership, trades, or purchases.

The window is drawn by [Meowthjrlib](https://github.com/Emmauwuuwu/Meowthjrlib), which the script loads for you, so
hotkeys, window size, themes, accent color, search and saved profiles all come from the library.

Made by meowthjr & Claude.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Emmauwuuwu/pistol-duels-skin-changer/main/PistolDuelsSkinChanger.lua"))()
```

## Features

- **Skins:** one box per weapon. Put any Glock, Tec-9, Deagle or Knife skin on your own weapon; Pattern and Wear
  appear only for patterned skins. Staff-only skins are listed and marked. Shuffle rolls a random skin each equip.
  A skin only shows on a weapon that is in your loadout.
- **Tint:** recolors a skin's own texture (blue on Emerald comes out blue-green). Each weapon keeps its own tint.
- **Ammo FX:** give each weapon any ammo FX (Reaper, Blaze, Static, Phantom, Frostbite, Tide, Rift, Starfall, Gale,
  Eclipse, Prism, or the Bloxxed kill effect): your tracer, sparks, muzzle flash, impacts, shot sound and kill effect
  change with it. Only you see it.
- **Effects:** bullet tracers on your own shots, and a spin on your own weapon model.
- **Boost:** more FPS. Lower graphics quality, FPS cap, and optionally no post effects, particles or decals, plus
  plain materials. Everything goes back when you turn it off.
- **Display:** stretched resolution, plus Meowthjrlib's own key viewer, watermark, active-module list and an
  FPS / ping widget. Drag them anywhere with Edit layout.
- **World:** color looks, glow and sun rays. They can only darken the map, never brighten it.
- **Camera:** motion blur on fast turns, field of view, weapon size and position.
- **Legit:** Silent Aim (head, body, closest part or weighted random), Triggerbot with a cooldown, No recoil, and
  Aim Assist with its own hold key, smoothing and FOV circle.
- **Rage:** ragebot, rapid fire, spinbot, third person (mouse wheel changes the distance) and air steering.
- **ESP:** boxes (2D, corners or 3D), R6/R15 skeleton, head dots, chams, glow, names, distance, health, weapon,
  status, tracers, snaplines, offscreen arrows, velocity, radar and a FOV circle, with teammate and
  practice-target filters.
- **Incognito:** changes what *your* screen shows — username, display name, avatar, server, level, coins, cash,
  ping and streak. Other players still see your real account; nothing is sent to the server.
- **Misc:** auto slide on jump (after each jump the slide key is pressed for you just before you land, so you land
  straight into a slide; hold jump to keep slide-jumping), free cursor, server hop by number, and auto load on
  server change.

Silent Aim changes shot direction, Aim Assist changes camera direction and does not fire for you, and the ESP and
FOV circles are overlays on your own screen. Silent Aim and Aim Assist have independent FOV radii and visibility
toggles: Aim Assist uses an orange outline, Silent Aim uses the menu accent color. Combat features are paused while
the menu is open, and optionally while you are in the lobby.

## How to use

1. Run `PistolDuelsSkinChanger.lua` in your executor while in Pistol Duels. It needs `setthreadidentity`, because the
   game's own modules have to be required from identity 2.
2. **RightShift** shows or hides the window, **RightCtrl** frees the cursor in first person. Both can be rebound on
   Meowthjrlib's own Settings page, along with the theme, accent color, window size and transparency.
3. Pick a weapon's box under **Skins** and choose a skin. A box's title or switch turns that module on, the key chip
   on a box sets its key, right-click a setting to reset it, and **Ctrl+F** searches every module and setting.

Settings are saved by Meowthjrlib to `Meowthjrlib/Pistol Duels/` in your executor's workspace folder, as named
profiles you can switch, export and import. Running the script again replaces the old copy cleanly, and
**Misc > Unload everything** undoes everything it changed.

## Privacy

While the script runs, it sends a ping every 30 seconds so the author can see how many people are using
it. The ping holds a random id made up for that run, a random id the script keeps in your executor's workspace
(`pistol_duels_online_id.txt`, so switching servers doesn't count you twice; delete the file to get a new one), and the
number of the server you're in (as shown in the game's server list, with its region).
Active pings also include your Roblox username for display on the public online counter.
Turning on **Incognito** stops the pings.

## Note

Using executors and third-party scripts is against Roblox's Terms of Use and can get an account banned. Use at your
own risk.
