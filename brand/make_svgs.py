"""Generates the Savanna Grass brand artwork as SVG (brand/svg/).

    python brand/make_svgs.py

One drawing, several cuts: the full app icon, Android adaptive-icon layers
(background, foreground, monochrome), and Twiga's head for in-app avatars.
Colours are SavannaTime's: positive green, deep green, dry-grass gold, cream.
Rendered to PNG by brand/render.mjs.
"""
from pathlib import Path

OUT = Path(__file__).parent / "svg"
OUT.mkdir(exist_ok=True)

GREEN_TOP = "#3A8A74"
GREEN = "#2F6F5E"
GREEN_DEEP = "#1F4D41"
HILL = "#163A30"
HILL_BACK = "#1B4438"
SUN = "#E5AB63"
CREAM = "#F7F1DE"
SPOT = "#D9A441"
INK = "#163A30"

# Twiga: a giraffe's neck and head rising out of the grass, looking at the sun.
# Drawn in a 1024 box; the head sits around (560, 380).
GIRAFFE = f"""
  <g id="twiga">
    <!-- neck -->
    <path d="M 352 1024 C 372 820 404 640 462 418 L 558 444 C 508 640 482 820 470 1024 Z" fill="{CREAM}"/>
    <!-- mane -->
    <path d="M 352 1024 C 372 820 404 640 462 418 L 440 412 C 382 640 350 820 330 1024 Z" fill="{SPOT}"/>
    <!-- spots -->
    <g fill="{SPOT}">
      <rect x="436" y="560" width="56" height="44" rx="16" transform="rotate(-8 464 582)"/>
      <rect x="412" y="660" width="62" height="50" rx="18" transform="rotate(6 443 685)"/>
      <rect x="402" y="770" width="58" height="52" rx="18" transform="rotate(-4 431 796)"/>
      <rect x="388" y="880" width="64" height="56" rx="20" transform="rotate(5 420 908)"/>
    </g>
    <!-- ossicones -->
    <g stroke="{CREAM}" stroke-width="22" stroke-linecap="round">
      <line x1="502" y1="352" x2="480" y2="262"/>
      <line x1="548" y1="344" x2="546" y2="252"/>
    </g>
    <circle cx="478" cy="254" r="22" fill="{SPOT}"/>
    <circle cx="546" cy="244" r="22" fill="{SPOT}"/>
    <!-- ear -->
    <ellipse cx="466" cy="374" rx="50" ry="21" fill="{CREAM}" transform="rotate(-24 466 374)"/>
    <!-- head -->
    <path d="M 456 412 C 452 354 520 328 592 340 C 652 350 702 388 718 428 C 730 460 708 486 674 486 C 632 484 600 468 560 462 C 502 456 458 450 456 412 Z" fill="{CREAM}"/>
    <!-- muzzle -->
    <path d="M 662 380 C 696 400 722 430 718 456 C 712 480 690 488 664 486 C 652 452 652 416 662 380 Z" fill="#EADFC2"/>
    <ellipse cx="700" cy="450" rx="7" ry="5" fill="{INK}" opacity="0.55"/>
    <!-- eye -->
    <circle cx="574" cy="386" r="15" fill="{INK}"/>
    <circle cx="579" cy="381" r="5" fill="{CREAM}"/>
  </g>
"""

SUN_ART = f'<circle cx="752" cy="300" r="118" fill="{SUN}"/>'

HILLS = f"""
  <path d="M -20 800 C 220 742 520 742 1044 780 L 1044 1044 L -20 1044 Z" fill="{HILL_BACK}"/>
  <path d="M -20 868 C 300 820 640 836 1044 884 L 1044 1044 L -20 1044 Z" fill="{HILL}"/>
  <g stroke="{HILL}" stroke-width="12" stroke-linecap="round">
    <line x1="140" y1="830" x2="122" y2="770"/><line x1="166" y1="826" x2="176" y2="772"/>
    <line x1="820" y1="840" x2="806" y2="786"/><line x1="846" y1="842" x2="860" y2="790"/>
    <line x1="660" y1="842" x2="668" y2="796"/>
  </g>
"""

BG_GRADIENT = f"""
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0.35" y2="1">
      <stop offset="0" stop-color="{GREEN_TOP}"/>
      <stop offset="0.55" stop-color="{GREEN}"/>
      <stop offset="1" stop-color="{GREEN_DEEP}"/>
    </linearGradient>
  </defs>
"""


def svg(body: str, defs: str = "") -> str:
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">'
        f"{defs}{body}</svg>"
    )


def scene() -> str:
    # The neck is drawn before the hills so it rises out of the grass.
    return SUN_ART + GIRAFFE + HILLS


# 1. App icon, square and full-bleed (iOS masks its own corners; Play too).
(OUT / "icon-square.svg").write_text(svg(f'<rect width="1024" height="1024" fill="url(#bg)"/>{scene()}', BG_GRADIENT))

# 2. Rounded icon for the web, favicon and legacy Android launchers.
(OUT / "icon-rounded.svg").write_text(svg(
    '<clipPath id="r"><rect width="1024" height="1024" rx="232"/></clipPath>'
    f'<g clip-path="url(#r)"><rect width="1024" height="1024" fill="url(#bg)"/>{scene()}</g>',
    BG_GRADIENT,
))

# 3. Android adaptive icon. The launcher masks a 108dp layer to ~72dp, so the
#    artwork is scaled into the central safe zone.
(OUT / "adaptive-background.svg").write_text(svg('<rect width="1024" height="1024" fill="url(#bg)"/>', BG_GRADIENT))
safe = 'transform="translate(512 512) scale(0.72) translate(-560 -560)"'
# The hills run far past the layer's edges so, once scaled into the safe zone,
# the grass still reaches the bottom of whatever shape the launcher masks to.
wide_hills = HILLS.replace("M -20 800", "M -600 806").replace("M -20 868", "M -600 880")     .replace("1044 780 L", "1700 830 L").replace("1044 884 L", "1700 940 L")     .replace("L 1044 1044 L -20 1044", "L 1700 1900 L -600 1900")
(OUT / "adaptive-foreground.svg").write_text(svg(f'<g {safe}>{SUN_ART}{GIRAFFE}{wide_hills}</g>'))

# 4. Android 13 themed icon: one-colour silhouette, tinted by the system.
mono = GIRAFFE.replace(CREAM, "#FFFFFF").replace(SPOT, "#FFFFFF").replace("#EADFC2", "#FFFFFF")
mono = mono.replace(f'fill="{INK}"', 'fill="#000" fill-opacity="0"')
(OUT / "adaptive-monochrome.svg").write_text(svg(
    f'<g {safe}><circle cx="752" cy="300" r="118" fill="#FFFFFF"/>{mono}</g>'
))

# 5. Twiga's head for in-app avatars (the app paints the disc behind it).
(OUT / "twiga-head.svg").write_text(svg(
    f'<g transform="translate(512 600) scale(1.5) translate(-580 -430)">{GIRAFFE}</g>'
))

print("wrote", ", ".join(sorted(p.name for p in OUT.glob("*.svg"))))
