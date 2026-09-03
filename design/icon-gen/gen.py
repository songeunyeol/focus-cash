import math
from PIL import Image, ImageDraw

S, OUT = 4096, 1024
C = S / 2
k = S / 1024.0

BG           = (0x07, 0x08, 0x0A, 255)
FLAME_DIM    = (0xC2, 0x5A, 0x18, 255)
FLAME        = (0xFF, 0x7A, 0x2F, 255)
FLAME_BRIGHT = (0xFF, 0xA1, 0x55, 255)
TIP          = (0xFF, 0xF2, 0xE4, 255)


def flame_poly(cx, base_y, height, width, lean, n=600):
    """진짜 불꽃 실루엣: 둥근 바닥 + 오목하게 수렴하는 뾰족한 끝 + 갈고리 기울기."""
    tp = 0.26                      # 가장 넓은 지점
    right, left = [], []
    for i in range(n + 1):
        t = i / n
        if t <= tp:
            w = width * math.sqrt(max(0.0, 1 - ((tp - t) / tp) ** 2))
        else:
            u = (t - tp) / (1 - tp)
            w = width * (1 - u) ** 1.55      # 오목한 테이퍼 -> 끝이 뾰족
        # 기울기: 아래는 곧고 위로 갈수록 갈고리처럼 휨
        dx = lean * (t ** 2.2)
        x, y = cx + dx, base_y - t * height
        right.append((x + w, y))
        left.append((x - w * 0.86, y))       # 비대칭
    return right + left[::-1]


img = Image.new("RGBA", (S, S), BG)
d = ImageDraw.Draw(img)

# ── 이중 링 ────────────────────────────────────────────
r_out, w_out = 356 * k, 52 * k                       # 두껍게: 작은 크기 가독성
d.ellipse([C - r_out, C - r_out, C + r_out, C + r_out],
          outline=FLAME_DIM, width=int(w_out))

r_in, w_in = 274 * k, 34 * k
d.arc([C - r_in, C - r_in, C + r_in, C + r_in],
      start=118, end=62, fill=FLAME, width=int(w_in))   # 하단 개구부 = 진행 링

# ── 3레이어 불꽃 ───────────────────────────────────────
# 안쪽 레이어는 lean 을 s**2.2 로 스케일해 바깥 레이어의 중심선 궤적을 그대로 탄다
# -> 끝이 절대 삐져나오지 않음
base_y = C + 190 * k
h  = 384 * k
w  = 122 * k
ln = 60 * k

for s, wf, col in ((1.00, 1.00, FLAME_DIM),
                   (0.76, 0.66, FLAME),
                   (0.52, 0.40, FLAME_BRIGHT),
                   (0.30, 0.24, TIP)):
    d.polygon(flame_poly(C, base_y, h * s, w * wf, ln * (s ** 2.2)), fill=col)

img = img.convert("RGB").resize((OUT, OUT), Image.LANCZOS)
img.save("icon_draft.png")

sheet = Image.new("RGB", (440, 240), (24, 24, 28))
x = 24
for sz in (192, 96, 48):
    sheet.paste(img.resize((sz, sz), Image.LANCZOS), (x, 24))
    x += sz + 28
sheet.save("preview_sheet.png")
print("done")
