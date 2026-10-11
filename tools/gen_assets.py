#!/usr/bin/env python3
"""Generate ToTAK's original CC0 pixel art, icons and sfx. Run: python3 tools/gen_assets.py"""
import math, random, struct, wave
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
T = 16
NAMES = ["floor_a", "floor_b", "wall", "stairs", "player", "orc", "troll", "corpse",
         "potion", "scroll", "dagger", "sword", "leather", "chain", "wall_face", "glow", "floor_blood", "wall_skull"]  # keep in sync with game/view/sprites.gd


def C(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) + (255,)


def noise(d, base, spread, seed, rect=(0, 0, T, T), density=0.5):
    r = random.Random(seed)
    for y in range(rect[1], rect[3]):
        for x in range(rect[0], rect[2]):
            v = r.randint(-spread, spread) if r.random() < density else 0
            d.point((x, y), tuple(max(0, min(255, c + v)) for c in base[:3]) + (255,))


def floor(seed):
    """Cold, damp flagstones with cracks and grime."""
    im = Image.new("RGBA", (T, T)); d = ImageDraw.Draw(im)
    noise(d, C("#403b3a"), 8, seed)
    grout = C("#1f1b1d")
    d.line([(0, 0), (T - 1, 0)], fill=grout); d.line([(0, 0), (0, T - 1)], fill=grout)
    d.line([(8, 0), (8, 7)], fill=grout); d.line([(0, 8), (T - 1, 8)], fill=grout)
    d.line([(4, 8), (4, T - 1)], fill=grout); d.line([(12, 8), (12, T - 1)], fill=grout)
    r = random.Random(seed * 7)
    for _ in range(3):                                   # grime
        x, y = r.randint(1, 14), r.randint(1, 14)
        d.point((x, y), fill=C("#2a2528"))
    x, y = r.randint(2, 10), r.randint(2, 10)            # crack
    d.line([(x, y), (x + 2, y + 1), (x + 3, y + 3)], fill=C("#1a1618"))
    return im


def floor_blood():
    im = floor(5); d = ImageDraw.Draw(im)
    d.ellipse([3, 4, 12, 11], fill=C("#4a0d10"))
    d.ellipse([5, 5, 10, 9], fill=C("#6b1216"))
    d.point((12, 12), fill=C("#4a0d10")); d.point((2, 12), fill=C("#4a0d10")); d.point((13, 3), fill=C("#4a0d10"))
    d.line([(6, 10), (8, 15)], fill=C("#4a0d10"))        # drag mark
    d.rectangle([9, 6, 12, 6], fill=C("#cfc8b0")); d.point((12, 7), fill=C("#cfc8b0"))   # a bone
    return im


def wall():
    im = Image.new("RGBA", (T, T)); d = ImageDraw.Draw(im)
    noise(d, C("#16131b"), 4, 7); return im


def wall_face():
    im = Image.new("RGBA", (T, T)); d = ImageDraw.Draw(im)
    noise(d, C("#4a4250"), 7, 11)
    mortar = C("#221e28")
    for y in (0, 5, 10, 15):
        d.line([(0, y), (T - 1, y)], fill=mortar)
    for i, y in enumerate((1, 6, 11)):
        off = 0 if i % 2 == 0 else 4
        for x in range(off, T, 8):
            d.line([(x, y), (x, y + 3)], fill=mortar)
    d.rectangle([0, 0, T - 1, 1], fill=C("#6a6070"))
    for x, y in [(3, 7), (4, 8), (11, 12), (12, 13), (9, 2)]:   # damp / moss streaks
        d.point((x, y), fill=C("#2c3a2c"))
    d.line([(6, 3), (6, 4)], fill=C("#4a0d10"))                 # old blood runs
    return im


def wall_skull():
    im = wall_face(); d = ImageDraw.Draw(im)
    d.rectangle([5, 4, 10, 9], fill=C("#d6cfb8"))              # skull set into the wall
    d.rectangle([6, 10, 9, 11], fill=C("#d6cfb8"))
    d.rectangle([6, 6, 7, 7], fill=C("#0c0a0e")); d.rectangle([8, 6, 9, 7], fill=C("#0c0a0e"))   # sockets
    d.point((7, 9), fill=C("#0c0a0e")); d.point((8, 9), fill=C("#0c0a0e"))
    d.point((6, 11), fill=C("#6b6455")); d.point((8, 11), fill=C("#6b6455"))
    return im


def stairs():
    im = floor(3); d = ImageDraw.Draw(im)
    d.rectangle([2, 2, 13, 13], fill=C("#050408"))
    for i in range(5):
        d.rectangle([2 + i, 3 + i * 2, 13 - i, 4 + i * 2], fill=C(["#6a6258", "#554e46", "#403a34", "#2a2622", "#15120f"][i]))
    d.point((7, 12), fill=C("#8a1414")); d.point((8, 12), fill=C("#8a1414"))   # something glows below
    return im


def spr(fn):
    im = Image.new("RGBA", (T, T), (0, 0, 0, 0)); d = ImageDraw.Draw(im); fn(d); return im


def player(d):
    """Haggard survivor: torn coat, pale scared face, wide eyes, guttering torch."""
    d.ellipse([3, 13, 12, 15], fill=(0, 0, 0, 120))
    d.rectangle([5, 12, 6, 14], fill=C("#2e2420")); d.rectangle([8, 12, 9, 14], fill=C("#2e2420"))   # boots
    d.rectangle([5, 10, 6, 12], fill=C("#3a3a30")); d.rectangle([8, 10, 9, 12], fill=C("#3a3a30"))   # trousers
    d.rectangle([4, 6, 10, 10], fill=C("#6e6048"))                                                   # coat
    d.line([(4, 10), (4, 11)], fill=C("#6e6048")); d.point((7, 11), fill=C("#6e6048")); d.point((9, 11), fill=C("#6e6048"))
    d.rectangle([4, 6, 10, 6], fill=C("#807458"))
    d.line([(5, 6), (9, 10)], fill=C("#3a2616"))                                                     # strap
    d.rectangle([9, 9, 11, 11], fill=C("#4a3320"))                                                   # satchel
    d.rectangle([5, 3, 9, 5], fill=C("#b8a090"))                                                     # pale face
    d.point((6, 4), fill=C("#f2f2e6")); d.point((8, 4), fill=C("#f2f2e6"))                           # wide eyes
    d.point((6, 3), fill=C("#1b1822")); d.point((8, 3), fill=C("#1b1822"))
    d.point((7, 5), fill=C("#6b1216"))                                                               # blood at mouth
    d.rectangle([4, 2, 10, 2], fill=C("#3a2a1a"))                                                    # hat brim
    d.rectangle([2, 3, 12, 3], fill=C("#2e2216"))
    d.rectangle([5, 0, 9, 2], fill=C("#4a3822")); d.line([(5, 2), (9, 2)], fill=C("#1b1612"))
    d.line([(3, 7), (2, 9)], fill=C("#6e6048"))
    d.line([(11, 6), (12, 4)], fill=C("#6e6048"))
    d.rectangle([12, 2, 12, 5], fill=C("#4a2a14"))
    d.rectangle([11, 0, 13, 2], fill=C("#d9701c")); d.point((12, 0), fill=C("#ffd070"))             # smaller, dimmer flame
    d.point((11, 0), fill=C("#9a2a10")); d.point((13, 1), fill=C("#9a2a10"))


def orc(d):
    """Ghoul: gaunt grey flesh, hunched, long clawed arms, burning white eyes."""
    d.ellipse([3, 13, 12, 15], fill=(0, 0, 0, 120))
    d.rectangle([5, 11, 6, 14], fill=C("#4a4a44")); d.rectangle([9, 11, 10, 14], fill=C("#4a4a44"))   # thin legs
    d.polygon([(4, 6), (11, 6), (12, 11), (3, 11)], fill=C("#5a5f52"))                                # hunched torso
    d.line([(5, 7), (5, 10)], fill=C("#2a2c26")); d.line([(7, 7), (7, 10)], fill=C("#2a2c26")); d.line([(9, 7), (9, 10)], fill=C("#2a2c26"))   # ribs
    d.rectangle([5, 2, 10, 6], fill=C("#7a8070"))                                                     # skull-like head
    d.rectangle([6, 3, 7, 4], fill=C("#050408")); d.rectangle([8, 3, 9, 4], fill=C("#050408"))
    d.point((7, 4), fill=C("#fff6d0")); d.point((9, 4), fill=C("#fff6d0"))                            # glowing eyes
    d.rectangle([6, 5, 9, 5], fill=C("#1a0608")); d.point((6, 5), fill=C("#d6cfb8")); d.point((8, 5), fill=C("#d6cfb8"))   # fanged maw
    d.line([(3, 7), (1, 12)], fill=C("#7a8070")); d.line([(12, 7), (14, 12)], fill=C("#7a8070"))      # long arms
    d.point((1, 13), fill=C("#d6cfb8")); d.point((14, 13), fill=C("#d6cfb8"))                         # claws


def troll(d):
    """Crypt abomination: hulking pale mass, exposed ribs, red burning eyes, huge maw."""
    d.ellipse([1, 13, 14, 15], fill=(0, 0, 0, 130))
    d.rectangle([3, 11, 6, 14], fill=C("#4a3a3a")); d.rectangle([9, 11, 12, 14], fill=C("#4a3a3a"))
    d.polygon([(2, 5), (13, 5), (14, 11), (1, 11)], fill=C("#6a5a58"))                               # massive body
    d.rectangle([4, 6, 11, 10], fill=C("#7a2a2a"))                                                    # torn open chest
    for x in (5, 7, 9, 11):
        d.line([(x, 6), (x, 10)], fill=C("#d6cfb8"))                                                  # ribs
    d.rectangle([5, 1, 10, 5], fill=C("#8a7a76"))                                                     # head
    d.rectangle([6, 2, 7, 3], fill=C("#ff2a1a")); d.rectangle([8, 2, 9, 3], fill=C("#ff2a1a"))       # red eyes
    d.rectangle([5, 4, 10, 5], fill=C("#1a0608"))                                                     # maw
    for x in (5, 7, 9):
        d.point((x, 4), fill=C("#d6cfb8"))
    d.rectangle([0, 6, 1, 12], fill=C("#8a7a76")); d.rectangle([14, 6, 15, 12], fill=C("#8a7a76"))   # huge arms
    d.rectangle([0, 12, 1, 14], fill=C("#d6cfb8")); d.rectangle([14, 12, 15, 14], fill=C("#d6cfb8"))


def corpse(d):
    d.ellipse([3, 9, 12, 14], fill=C("#5a1414")); d.ellipse([5, 10, 10, 13], fill=C("#8a1c1c"))
    d.line([(4, 8), (7, 11)], fill=C("#d9d2c5")); d.line([(10, 8), (8, 11)], fill=C("#d9d2c5"))


def potion(d):
    d.ellipse([4, 7, 11, 14], fill=C("#b02a5a")); d.ellipse([5, 8, 8, 10], fill=C("#f06a9a"))
    d.rectangle([6, 3, 9, 7], fill=C("#cfe3ee")); d.rectangle([6, 2, 9, 3], fill=C("#8a5a2a"))


def scroll(d):
    d.rectangle([3, 4, 12, 12], fill=C("#e8e0c4")); d.rectangle([2, 3, 3, 13], fill=C("#b8a57a"))
    d.rectangle([12, 3, 13, 13], fill=C("#b8a57a"))
    for y in (6, 8, 10):
        d.line([(5, y), (10, y)], fill=C("#8a7a55"))


def dagger(d):
    d.line([(4, 12), (11, 4)], fill=C("#cfd6e0"), width=2); d.line([(3, 13), (5, 11)], fill=C("#8a5a2a"), width=2)
    d.line([(6, 9), (8, 11)], fill=C("#c8a14a"))


def sword(d):
    d.line([(3, 13), (12, 3)], fill=C("#e6ecf4"), width=2); d.line([(5, 9), (8, 12)], fill=C("#c8a14a"), width=2)
    d.line([(2, 14), (4, 12)], fill=C("#6b3a1a"), width=2)


def leather(d):
    d.polygon([(3, 4), (6, 3), (10, 3), (13, 4), (12, 13), (4, 13)], fill=C("#8a5a2a"))
    d.rectangle([6, 3, 9, 5], fill=C("#1b1822")); d.line([(8, 6), (8, 13)], fill=C("#5a3a1a"))


def chain(d):
    d.polygon([(3, 4), (6, 3), (10, 3), (13, 4), (12, 13), (4, 13)], fill=C("#9aa3b0"))
    d.rectangle([6, 3, 9, 5], fill=C("#1b1822"))
    for y in range(6, 13, 2):
        for x in range(4 + (y // 2) % 2, 12, 2):
            d.point((x, y), fill=C("#d6dce6"))


def glow():
    im = Image.new("RGBA", (T, T), (0, 0, 0, 0)); d = ImageDraw.Draw(im); return im


def build_tiles():
    sheet = Image.new("RGBA", (T * len(NAMES), T), (0, 0, 0, 0))
    made = {"floor_a": floor(1), "floor_b": floor(2), "wall": wall(), "stairs": stairs(),
            "wall_face": wall_face(), "glow": glow(),
            "floor_blood": floor_blood(), "wall_skull": wall_skull()}
    for n, fn in dict(player=player, orc=orc, troll=troll, corpse=corpse, potion=potion, scroll=scroll,
                      dagger=dagger, sword=sword, leather=leather, chain=chain).items():
        made[n] = spr(fn)
    for i, n in enumerate(NAMES):
        sheet.paste(made[n], (i * T, 0))
    sheet.save(ROOT / "assets/tiles.png")


def build_save_icon():
    """16x16 floppy disk for the quick-save button."""
    im = Image.new("RGBA", (T, T), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.rectangle([1, 1, 14, 14], fill=C("#2f4f8a"), outline=C("#1b1822"))
    d.rectangle([4, 1, 11, 5], fill=C("#c9ced8"))                         # metal shutter
    d.rectangle([8, 2, 10, 4], fill=C("#5a6272"))
    d.rectangle([3, 8, 12, 14], fill=C("#e8e0c4"), outline=C("#1b1822"))  # label
    d.line([(5, 10), (10, 10)], fill=C("#8a7a55")); d.line([(5, 12), (10, 12)], fill=C("#8a7a55"))
    im.save(ROOT / "assets/save_icon.png")


def build_icons():
    big = Image.new("RGBA", (256, 256), C("#1b1822")); d = ImageDraw.Draw(big)
    d.rounded_rectangle([8, 8, 247, 247], 40, fill=C("#2b2733"), outline=C("#c8a14a"), width=6)
    p = Image.new("RGBA", (T, T), (0, 0, 0, 0)); player(ImageDraw.Draw(p))
    big.alpha_composite(p.resize((176, 176), Image.NEAREST), (40, 36))
    big.save(ROOT / "assets/icon.png")
    big.save(ROOT / "assets/icon.ico", sizes=[(256, 256), (64, 64), (48, 48), (32, 32), (16, 16)])
    big.save(ROOT / "assets/icon.icns")


def tone(name, freqs, dur, vol=0.35, noise_mix=0.0, rate=22050):
    r = random.Random(5); n = int(rate * dur); out = []
    for i in range(n):
        t = i / rate; f = freqs[0] + (freqs[-1] - freqs[0]) * (i / n)
        v = math.sin(2 * math.pi * f * t) * (1 - noise_mix) + r.uniform(-1, 1) * noise_mix
        out.append(int(32767 * vol * v * (1 - i / n) ** 1.5))
    with wave.open(str(ROOT / f"assets/sfx/{name}.wav"), "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate)
        w.writeframes(b"".join(struct.pack("<h", s) for s in out))


def drone(name="ambient", dur=8.0, rate=22050):
    """Low, slowly beating tomb drone with breathy noise; loops seamlessly (whole number of cycles)."""
    r = random.Random(11); n = int(rate * dur); out = []
    prev = 0.0
    for i in range(n):
        t = i / rate
        v = 0.5 * math.sin(2 * math.pi * 55 * t) + 0.4 * math.sin(2 * math.pi * 58 * t) + 0.18 * math.sin(2 * math.pi * 110.5 * t)
        prev = prev * 0.97 + r.uniform(-1, 1) * 0.03            # low-passed noise = distant wind
        v += prev * 2.2
        v *= 0.55 + 0.45 * math.sin(2 * math.pi * t / dur)       # slow swell, period = loop length
        out.append(int(32767 * 0.34 * v))
    with wave.open(str(ROOT / f"assets/sfx/{name}.wav"), "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate)
        w.writeframes(b"".join(struct.pack("<h", max(-32767, min(32767, s))) for s in out))


def heartbeat(rate=22050):
    out = []
    for beat_at in (0.0, 0.22):
        pass
    n = int(rate * 0.7); buf = [0.0] * n
    for start, amp in ((0.0, 1.0), (0.2, 0.7)):
        for i in range(int(rate * 0.16)):
            t = i / rate; k = int((start * rate)) + i
            if k < n:
                buf[k] += amp * math.sin(2 * math.pi * 60 * t) * (1 - i / (rate * 0.16)) ** 2
    with wave.open(str(ROOT / "assets/sfx/heartbeat.wav"), "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate)
        w.writeframes(b"".join(struct.pack("<h", int(32767 * 0.7 * v)) for v in buf))


def build_sfx():
    drone(); heartbeat()
    tone("hit", [150, 55], 0.2, noise_mix=0.55); tone("miss", [300, 200], 0.08, vol=0.15, noise_mix=0.8)
    tone("pickup", [300, 420], 0.12); tone("use", [400, 800, 1200][::2], 0.25); tone("stairs", [260, 60], 0.7)
    tone("die", [120, 30], 0.9, noise_mix=0.4); tone("levelup", [220, 330], 0.6); tone("step", [90, 70], 0.05, vol=0.12, noise_mix=0.6)


if __name__ == "__main__":
    build_tiles(); build_icons(); build_save_icon(); build_sfx(); print("assets written")
