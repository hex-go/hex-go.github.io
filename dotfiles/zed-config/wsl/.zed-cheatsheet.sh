#!/usr/bin/env bash
# Zed + opencode + vim shortcut cheat sheet. Invoked by Zed task "Shortcut Cheat Sheet".
# Press Esc or q to close.

clear
cols=$( (stty size 2>/dev/null || echo "24 80") | awk '{print $2}')
[ -z "$cols" ] && cols=80

COLS="$cols" python3 - <<'PY'
import os, sys, unicodedata

tty = sys.stdout.isatty()
def sgr(code, s):
    return f"\033[{code}m{s}\033[0m" if tty else s
CY, YE, GR, MG = "1;36", "1;33", "1;32", "1;35"
HEAD = "1;30;46"
DIM  = "2"

def w(s):
    return sum(2 if unicodedata.east_asian_width(ch) in "WF" else 1 for ch in s)

def header(title, colcode):
    return ("H", colcode, title)
def row(k, d):
    return ("R", k, d)
def blank():
    return ("B", "", "")

left = [
    header("ZED · 键盘导航", "1;30;43"),
    row("ctrl+shift+/",     "显示本速查表"),
    row("ctrl+k ctrl+s",    "浏览全部快捷键"),
    blank(),
    row("ctrl+shift+enter", "主区新建终端"),
    row("ctrl+shift+\\",    "左右分屏"),
    row("ctrl+shift+w",     "关闭标签页"),
    row("ctrl+k ctrl+←/→",  "切换分屏焦点"),
    row("ctrl+tab",         "下一个标签"),
    row("ctrl+shift+tab",   "上一个标签"),
    blank(),
    row("ctrl+shift+p",     "命令面板 (万能入口)"),
    row("ctrl+shift+e",     "聚焦文件树"),
    row("ctrl+`",           "切换底部终端"),
    blank(),
    row("ctrl+shift+f",     "文件内容搜索"),
    row("ctrl+p",           "文件名搜索"),
    blank(),
    header("OPENCODE · 输入编辑", "1;30;42"),
    row("ctrl+a · ctrl+e",  "行首 · 行尾"),
    row("ctrl+b · ctrl+f",  "字符左移 · 右移"),
    row("ctrl+← · ctrl+→",  "单词左移 · 右移"),
    blank(),
    row("ctrl+w",           "删除前一个单词"),
    row("ctrl+u",           "删除至行首"),
    row("ctrl+k",           "删除至行尾"),
    blank(),
    row("ctrl+z",           "撤销"),
    blank(),
    header("OPENCODE · 命令 (leader=ctrl+x)", "1;30;42"),
    row("ctrl+x n",         "新会话"),
    row("ctrl+x l",         "会话列表"),
    row("ctrl+x m",         "模型列表"),
    row("ctrl+x a",         "Agent 列表"),
    row("ctrl+x s",         "状态视图"),
    row("ctrl+x e",         "外部编辑器打开输入框"),
    row("ctrl+x u",         "撤销上一条消息"),
    row("ctrl+x c",         "压缩会话"),
    row("ctrl+x p",         "命令列表"),
    row("tab · shift+tab",  "切换 Agent"),
    row("f2  · shift+f2",    "循环最近模型"),
]

right = [
    header("VIM · 编辑 (Normal)", "1;30;45"),
    row("h|j|k|l",     "左 下 上 右"),
    row("w|b|e",       "下词 · 上词 · 词尾"),
    row("0|$|^",       "行首 · 行尾 · 首非空"),
    row("gg|G",        "文件开头 · 末尾"),
    row("%",           "跳到匹配括号 (双向)"),
    blank(),
    row("i|a|o",       "插入：光标-前、后、下"),
    row("I|A|O",       "插入：行-首、尾、上方"),
    blank(),
    row("x|dd|dw",     "删除：字符 ╎ 整行 ╎ 单词"),
    row("d$|d0|dG",    "删除：行尾 ╎ 行首 ╎ 文末"),
    row("cc|cw|C",     "修改：行   ╎ 词   ╎ 至行尾"),
    row('ci"|ci(|ciw', "修改：引号 ╎ 括号 ╎ 单词内"),
    row("yy|yw|:%y|p", "复制：行   ╎ 词   ╎ 全文 ╎ 粘贴"),
    blank(),
    row("u      · g- · :undo",    "撤销 :earlier 5s 按时间回退"),
    row("ctrl+r · g+ · :redo", "重做 :later 5s 按时间前进"),
    row("/str   → n · N",   "搜索：下个 · 上个  ·  :set is 增量  :set hls 高亮"),
    row(":%s/old/new/g",   "替换 (加 c 确认)"),
    blank(),
    header("VIM · 可视 / 列块", "1;30;45"),
    row("v V ctrl+v",  "进入：字符 · 行 · 列块 选择"),
    row("I · A",       "列块批量 行首插入 · 行尾追加"),
    row("c · d · x",   "c=改  d,x=删 选中块"),
    row("> · <",       "缩进 · 反缩进"),
    blank(),
    header("VIM · 多文件 / 窗口 / 寄存器", "1;30;46"),
    row("vim f1 f2",   "打开多个文件"),
    row(":Ex",         "打开当前目录 j/k 移动 回车打开"),
    row(":e f1",       "打开文件 (补全用:Ex更好)"),
    row(":ls",         "LS 已打开文件"),
    row(":b num · :b f1", "跳转：根据文件号 · 根据文件名 (:ls 查看)"),
    row(":bn    · :bp",   "跳转：下一个文件 · 上一个文件"),
    row(":bd",         "关闭当前文件 (:q 关闭全部)"),
    blank(),
    row(":sp f1 · :vs f1", "分屏：水平 · 垂直 打开文件 (:q 关闭)"),
    row("ctrl+w → hjkl", "分屏：窗口间移动"),
    blank(),
    row('"a → yy',     "命名寄存器：存入变量a"),
    row('"a → p',      "命名寄存器：粘贴变量a"),
]

def strip_w(s):
    import re
    return w(re.sub(r"\033\[[0-9;]*m", "", s))

CAP = "1;38;5;253;48;5;238"   # keycap: bold light text on dark-grey bg (shadow look)
PLUS = sgr(DIM, "+")
VIM_PRIMARY = "1;36"          # primary vim shortcut: bold cyan
VIM_ALT     = "2;36"          # alternative vim shortcut: dim cyan
VIM_BAR     = "╎"             # parallel-key separator: light double-dash vertical

def keycap(text):
    groups = text.split(" ")
    out = []
    for g in groups:
        if g == "":
            out.append("")
        elif g == "/" or g == "·":
            out.append(sgr(DIM, g))
        else:
            caps = [sgr(CAP, f" {p} ") for p in g.split("+")]
            out.append(PLUS.join(caps))
    return " ".join(out)

def vim_key(text):
    if " → " in text:
        cmd, rest = text.split(" → ", 1)
        return sgr(CY, cmd) + sgr(DIM, " → ") + vim_key(rest)
    if " · " in text:
        parts = text.split(" · ")
        rendered = [sgr(VIM_PRIMARY, parts[0])]
        for p in parts[1:]:
            rendered.append(sgr(VIM_ALT, p))
        return sgr(DIM, " · ").join(rendered)
    if "|" in text:
        parts = text.split("|")
        padded = [p + " " * max(0, 3 - w(p)) for p in parts]
        return sgr(DIM, f" {VIM_BAR} ").join(sgr(CY, p) for p in padded)
    if text == "v V ctrl+v":
        return sgr(DIM, f" {VIM_BAR} ").join([
            sgr("2;36", "v"), sgr("36", "V"), sgr("1;36", "ctrl+v")])
    return sgr(CY, text)

def keyw(items, cap):
    m = 0
    for t, k, d in items:
        if t == "R":
            kr = keycap(k) if cap else vim_key(k)
            m = max(m, strip_w(kr))
    return m
lk = keyw(left, True); rk = keyw(right, False)

def render(item, kw, cap):
    t, a, b = item
    if t == "B":
        return ""
    if t == "H":
        return sgr(a, f" {b} ")
    kr = keycap(a) if cap else vim_key(a)
    pad = " " * (kw - strip_w(kr))
    return kr + pad + "  " + b

total = int(os.environ.get("COLS", "80"))
def blockw(items, kw):
    m = 0
    for t,a,b in items:
        if t=="H": m=max(m, w(b)+2)
        elif t=="R": m=max(m, kw+2+w(b))
    return m
lw = blockw(left, lk)
GAP = 4        # columns gap in spaces (was " │ " before)
two_col = total >= lw + GAP + blockw(right, rk) + 4

title = "ZED + OPENCODE + VIM  CHEAT SHEET"
print()
print("  " + sgr("1;37;44", f"  {title}  "))
print()

if two_col:
    n = max(len(left), len(right))
    for i in range(n):
        l = render(left[i], lk, True)   if i < len(left)  else ""
        r = render(right[i], rk, False) if i < len(right) else ""
        pad = " " * (lw - strip_w(l))
        print("  " + l + pad + " " * GAP + r)
else:
    for it in left:
        print("  " + render(it, lk, True))
    print()
    for it in right:
        print("  " + render(it, rk, False))

print()
print("  " + sgr(GR, "▸ 按 Esc 或 q 关闭本页"))
print()
PY

esc=$(printf '\033')
while true; do
  IFS= read -rsn1 k
  [ "$k" = q ] && break
  [ "$k" = "$esc" ] && break
done
clear
