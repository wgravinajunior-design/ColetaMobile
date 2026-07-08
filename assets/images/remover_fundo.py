"""
Remove o fundo branco de fora do circulo da logo,
deixando somente o circulo com fundo transparente.
Executa: python remover_fundo.py
Requer: pip install Pillow
"""
from PIL import Image, ImageDraw
import math, os

INPUT  = os.path.join(os.path.dirname(__file__), "logo.png")
OUTPUT = os.path.join(os.path.dirname(__file__), "logo.png")   # sobrescreve

img = Image.open(INPUT).convert("RGBA")
w, h = img.size

# Mascara circular centrada
mask = Image.new("L", (w, h), 0)
draw = ImageDraw.Draw(mask)
cx, cy = w // 2, h // 2
r = min(cx, cy) - 2          # raio = metade do menor lado - 2px de margem
draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=255)

# Aplicar mascara: pixels fora do circulo ficam transparentes
img.putalpha(mask)

img.save(OUTPUT, "PNG")
print(f"Salvo: {OUTPUT} ({w}x{h}px)")
