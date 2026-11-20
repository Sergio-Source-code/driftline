"""Draw Driftline's original flat icon at build time; no binary art is stored."""
import json
import math
import os
import struct
import sys
import zlib

SIZE = 1024
pixels = bytearray(SIZE * SIZE * 3)


def color(hex_value):
    return bytes(((hex_value >> 16) & 255, (hex_value >> 8) & 255, hex_value & 255))


def span(y, left, right, ink):
    if y < 0 or y >= SIZE:
        return
    left, right = max(0, int(left)), min(SIZE, int(right) + 1)
    if right > left:
        start = (y * SIZE + left) * 3
        pixels[start:start + (right - left) * 3] = ink * (right - left)


def rect(x0, y0, x1, y1, hex_value):
    ink = color(hex_value)
    for y in range(max(0, y0), min(SIZE, y1)):
        span(y, x0, x1, ink)


def polygon(points, hex_value):
    ink = color(hex_value)
    for y in range(max(0, int(min(p[1] for p in points))), min(SIZE, int(max(p[1] for p in points)) + 1)):
        crossings = []
        for a, b in zip(points, points[1:] + points[:1]):
            if (a[1] <= y < b[1]) or (b[1] <= y < a[1]):
                crossings.append(a[0] + (y - a[1]) * (b[0] - a[0]) / (b[1] - a[1]))
        crossings.sort()
        for left, right in zip(crossings[::2], crossings[1::2]):
            span(y, math.ceil(left), math.floor(right), ink)


def circle(cx, cy, radius, hex_value):
    ink = color(hex_value)
    for y in range(max(0, cy - radius), min(SIZE, cy + radius + 1)):
        extent = math.sqrt(max(0, radius * radius - (y - cy) ** 2))
        span(y, cx - extent, cx + extent, ink)


# Warm sunset, bold skyline, converging road and a yellow sports car.
rect(0, 0, SIZE, SIZE, 0xF57848)
rect(0, 360, SIZE, 620, 0xFFB642)
circle(512, 344, 224, 0xFFE19B)
rect(0, 462, SIZE, 478, 0xFFB642)
rect(0, 503, SIZE, 523, 0xFFB642)
for x, top, width in [(0, 387, 95), (100, 303, 85), (194, 360, 83), (287, 254, 95),
                      (392, 388, 64), (579, 342, 66), (654, 284, 103), (770, 355, 76),
                      (856, 236, 92), (958, 361, 66)]:
    rect(x, top, x + width, 614, 0x805B70)
    if top < 320:
        rect(x + width // 2 - 3, top - 28, x + width // 2 + 3, top, 0x805B70)
    for y in range(top + 25, 560, 38):
        rect(x + 15, y, x + width - 15, y + 8, 0xDDA482)
rect(0, 572, SIZE, SIZE, 0x328E8C)
polygon([(430, 567), (594, 567), (1024, 1024), (0, 1024)], 0x324552)
polygon([(426, 567), (439, 567), (70, 1024), (24, 1024)], 0xF2D8B0)
polygon([(585, 567), (598, 567), (1000, 1024), (954, 1024)], 0xF2D8B0)
polygon([(509, 581), (515, 581), (520, 619), (504, 619)], 0xF7D896)
polygon([(502, 641), (522, 641), (529, 696), (495, 696)], 0xF7D896)
polygon([(494, 936), (530, 936), (540, 1024), (484, 1024)], 0xF7D896)
# Low, wide silhouette viewed from behind.
polygon([(270, 830), (754, 830), (806, 919), (218, 919)], 0x253541)
rect(268, 800, 326, 916, 0x1C2C38)
rect(698, 800, 756, 916, 0x1C2C38)
polygon([(325, 713), (374, 640), (650, 640), (699, 713), (746, 752),
         (763, 862), (729, 895), (295, 895), (261, 862), (278, 752)], 0xFFC83D)
polygon([(348, 718), (392, 660), (632, 660), (676, 718)], 0x345565)
polygon([(392, 660), (632, 660), (643, 675), (383, 675)], 0x638C93)
polygon([(281, 770), (743, 770), (753, 814), (271, 814)], 0xFFDE60)
polygon([(271, 814), (753, 814), (746, 866), (278, 866)], 0xF3AC2B)
rect(283, 820, 410, 842, 0xF26145)
rect(614, 820, 741, 842, 0xF26145)
rect(424, 827, 600, 847, 0x344852)
rect(301, 866, 723, 885, 0x273D49)
rect(299, 750, 315, 774, 0xC18D2B)
rect(709, 750, 725, 774, 0xC18D2B)
polygon([(271, 741), (753, 741), (770, 759), (254, 759)], 0xFFDC62)


def chunk(kind, data):
    return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)


output = sys.argv[1]
os.makedirs(output, exist_ok=True)
raw = b''.join(b'\x00' + bytes(pixels[y * SIZE * 3:(y + 1) * SIZE * 3]) for y in range(SIZE))
png = b'\x89PNG\r\n\x1a\n'
png += chunk(b'IHDR', struct.pack('>IIBBBBB', SIZE, SIZE, 8, 2, 0, 0, 0))
png += chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')
with open(os.path.join(output, 'DriftlineIcon.png'), 'wb') as handle:
    handle.write(png)
with open(os.path.join(output, 'Contents.json'), 'w') as handle:
    json.dump({'images': [{'filename': 'DriftlineIcon.png', 'idiom': 'universal', 'platform': 'ios', 'size': '1024x1024'}],
               'info': {'author': 'xcode', 'version': 1}}, handle)
print('Generated original 1024px Driftline icon')
