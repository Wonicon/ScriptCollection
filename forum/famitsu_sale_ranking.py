import win32clipboard
from logging import Handler
from matplotlib.lines import Line2D
import matplotlib.pyplot as plt
import matplotlib.font_manager as font_manager
from datetime import *
from matplotlib.patches import PathPatch
from matplotlib.offsetbox import OffsetImage, AnnotationBbox
from matplotlib.patches import PathPatch
from matplotlib.offsetbox import OffsetImage, AnnotationBbox
import numpy as np
from PIL import Image

win32clipboard.OpenClipboard()
sales_text = win32clipboard.GetClipboardData()
win32clipboard.CloseClipboard()

lines = sales_text.split("\n")
lines = [line.split("（累計")[0] for line in lines]
platform_sales = [line.split("／") for line in lines]

def cjk_to_int(s: str):
    s = s.replace("台", "")
    if "万" in s:
        first, second = s.split("万")
        value = int(first) * 10000 + int(second)
    else:
        value = int(s)
    return value

#platform_sales = dict(map(lambda e: [e[0], cjk_to_int(e[1])], platform_sales))

order = [
    "PS5 Pro",
    "PS5",
    "PS5 デジタル・エディション",
    "PS4",
    "Xbox Series X",
    "Xbox Series X デジタルエディション",
    "Xbox Series S",
    "Switch Lite",
    "Switch",
    "Nintendo Switch（有機ELモデル）",
]

sales = [3418, 10321, 1527, 27, 19, 53, 190, 5978, 3042, 11055]
if False:
    for plat in order:
        sales.append(platform_sales[plat])
    print(f"sales = [{', '.join(map(str, sales))}]")

labels = [
    "PS5 Pro",
    "PS5",
    "PS5 digital",
    "PS4",
    "XSX",
    "XSX digital",
    "XSS",
    "Switch Lite",
    "Switch",
    "Swtich OLED",
]

colors = [
    '#121a4d',
    '#203864',
    '#203864',
    '#4472C4',
    '#385723',
    '#385723',
    '#385723',
    '#ff0000',
    '#C00000',
    '#A20000',
]

def img_to_pie(fn, wedge, xy, zoom=1, ax = None):
    if ax==None: ax=plt.gca()

    ang = (wedge.theta2 - wedge.theta1)/2. + wedge.theta1
    r = wedge.r / 2
    # 计算坐标位置
    x = r * np.cos(np.deg2rad(ang))
    y = r * np.sin(np.deg2rad(ang))

    im = plt.imread(fn, format='jpg')
    path = wedge.get_path()
    patch = PathPatch(path, facecolor='none')
    ax.add_patch(patch)
    imagebox = OffsetImage(im, zoom=zoom, clip_path=patch, zorder=-10)
    ab = AnnotationBbox(imagebox, (x, y), xycoords='data', pad=0, frameon=False)
    ax.add_artist(ab)

fig, ax = plt.subplots()
wedges, texts = ax.pie(
    sales,
    colors=colors,
    startangle=90,
    counterclock=False,
    wedgeprops={"linewidth": 1, "edgecolor": "white"}
    )

# make the following into list
images = []

for wedge, image, label in zip(wedges, images, labels):
    img_to_pie(image, wedge, (0,0), zoom=0.5, ax=ax)

ax.axis('equal')  # Equal aspect ratio ensures that pie is drawn as a circle.
legend_elements = [Line2D([], [], marker='s', color='y', markerfacecolor=c, markeredgecolor=c, lw=0, markersize=5, label=l) for l, c in zip(labels, colors)]
font = font_manager.FontProperties(family='Comic Sans MS', style='normal', size=6)
plt.legend(
    handles=legend_elements,
    loc='lower center',
    handlelength=0.5,
    fontsize='xx-small',
    frameon=False,
    prop=font,
    ncol=len(labels)
    )
plt.tight_layout()

now = datetime.now()
delta = timedelta(days=4+6)
start = now - delta
end = start + timedelta(days=6)
start_fmt = "%Y/%m/%d"
if start.year == end.year:
    end_fmt = "%m/%d"
else:
    end_fmt = "%y/%m/%d"

title = f"FAMI销量{start.strftime(start_fmt)}~{end.strftime(end_fmt)}"
print(f"[{title}]")

filename = title.replace("/", "-").replace("~", "_")
plt.savefig(f"C:/Users/{os.getlogin()}/Pictures/{filename}.png", dpi=350)
