# Changelog

Release notes for every version are generated automatically from the commit log and published on the
[Releases page](https://github.com/AWeebTaku/ToTAK/releases). This file records milestones only.

## First Godot release (v0.1.0)
Complete remake in Godot 4 (the original Python/ASCII game lives on in `legacy/`).

- **Look and feel:** pixel-art horror: dark tombs that get gloomier each floor, flickering torch light, vignette and film
  grain, blood-stained floors and skull walls, ghoul and abomination enemies, tomb drone and heartbeat audio.
- **Interface:** minimap that fills as you explore, bottom-centre hotbar (keys 1-9 and 0, mouse wheel to scroll), clickable
  health strip that opens the character sheet, auto-hiding message log, pause button, red X and click-outside to close menus.
- **Gameplay:** WASD / arrows / numpad / vi movement with hold-to-walk, stackable consumables, quick-heal (`Q`),
  quick-save (`F5`), autosave every turn, XP and level-ups (the original never awarded XP).
- **Platform:** Windows installer, macOS dmg, Linux AppImage and tarball, built and released automatically.
  In-game update notices, versioned saves with migrations.
- **Other fixes versus the original:** one death message, inventory index off-by-one, fireball radius preview, nothing spawns
  on the player's tile, health potions heal 10 instead of 4.
