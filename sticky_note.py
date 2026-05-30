import tkinter as tk
from tkinter import messagebox, ttk, colorchooser, simpledialog
import json
import os
import sys
import subprocess
import threading
import time
import ctypes
import math
import urllib.parse
import urllib.request
from datetime import datetime, timedelta
from PIL import Image, ImageTk

try:
    import winreg
except ImportError:
    winreg = None

try:
    from zhdate import ZhDate
    ZHDATE_OK = True
except ImportError:
    ZHDATE_OK = False

try:
    import cnlunar
    CNLUNAR_OK = True
except ImportError:
    CNLUNAR_OK = False

def _app_dir():
    """获取程序所在目录（兼容开发环境和 PyInstaller 打包后）"""
    if getattr(sys, 'frozen', False):
        return os.path.dirname(sys.executable)
    return os.path.dirname(os.path.abspath(__file__))

DATA_FILE = os.path.join(_app_dir(), "notes.json")
WEATHER_UPDATE_INTERVAL_MS = 30 * 60 * 1000
WEATHER_RETRY_INTERVAL_MS = 5 * 60 * 1000
HTTP_TIMEOUT = 10
STARTUP_REG_PATH = r"Software\Microsoft\Windows\CurrentVersion\Run"
STARTUP_REG_NAME = "雨然日历"

DEFAULT_COLORS = {
    "yellow": {"bg": "#FFF9C4", "fg": "#212121", "today": "#FF9800", "holiday": "#D32F2F", "weekend": "#FFE0B2"},
    "green":  {"bg": "#C8E6C9", "fg": "#1B5E20", "today": "#2E7D32", "holiday": "#D32F2F", "weekend": "#A5D6A7"},
    "blue":   {"bg": "#BBDEFB", "fg": "#0D47A1", "today": "#1565C0", "holiday": "#D32F2F", "weekend": "#90CAF9"},
    "pink":   {"bg": "#F8BBD9", "fg": "#880E4F", "today": "#C2185B", "holiday": "#D32F2F", "weekend": "#F48FB1"},
    "purple": {"bg": "#E1BEE7", "fg": "#4A148C", "today": "#6A1B9A", "holiday": "#D32F2F", "weekend": "#CE93D8"},
    "white":  {"bg": "#FFFFFF", "fg": "#212121", "today": "#1976D2", "holiday": "#D32F2F", "weekend": "#EEEEEE"},
    "dark":   {"bg": "#263238", "fg": "#FFFFFF", "today": "#FF9800", "holiday": "#FF5252", "weekend": "#37474F"},
}

WEEKDAYS = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
WEEKDAYS_SHORT = ["一", "二", "三", "四", "五", "六", "日"]

WEATHER_CODE_TEXT = {
    0: "晴",
    1: "晴间多云",
    2: "多云",
    3: "阴",
    45: "雾",
    48: "雾凇",
    51: "小毛雨",
    53: "毛毛雨",
    55: "大毛雨",
    56: "冻毛雨",
    57: "强冻毛雨",
    61: "小雨",
    63: "中雨",
    65: "大雨",
    66: "冻雨",
    67: "强冻雨",
    71: "小雪",
    73: "中雪",
    75: "大雪",
    77: "雪粒",
    80: "阵雨",
    81: "强阵雨",
    82: "暴阵雨",
    85: "阵雪",
    86: "强阵雪",
    95: "雷雨",
    96: "雷暴冰雹",
    99: "强雷暴冰雹",
}

WEATHER_ICON_DEFAULT = "○"

LUNAR_MONTHS = ["正", "二", "三", "四", "五", "六", "七", "八", "九", "十", "冬", "腊"]
LUNAR_DAYS = ["初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
              "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
              "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十"]

# 固定公历节假日
SOLAR_HOLIDAYS = {
    (1, 1): "元旦",
    (2, 14): "情人节",
    (3, 5): "学雷锋",
    (3, 8): "妇女节",
    (3, 12): "植树节",
    (3, 15): "消权日",
    (4, 1): "愚人节",
    (5, 1): "劳动节",
    (5, 4): "青年节",
    (5, 12): "护士节",
    (6, 1): "儿童节",
    (6, 5): "环境日",
    (7, 1): "建党节",
    (7, 7): "抗战纪念",
    (8, 1): "建军节",
    (8, 8): "父亲节",
    (9, 3): "抗战胜利",
    (9, 10): "教师节",
    (9, 18): "九一八",
    (9, 30): "烈士纪念",
    (10, 1): "国庆节",
    (10, 24): "程序员节",
    (10, 31): "万圣节",
    (11, 11): "光棍节",
    (12, 4): "宪法日",
    (12, 13): "国家公祭",
    (12, 24): "平安夜",
    (12, 25): "圣诞节",
    (12, 26): "伟人诞辰",
}

# 农历节假日（月份, 日）
LUNAR_HOLIDAYS = {
    (1, 1): "春节",
    (1, 15): "元宵节",
    (2, 2): "龙抬头",
    (2, 19): "观音诞",
    (3, 3): "上巳节",
    (4, 8): "佛诞",
    (5, 5): "端午节",
    (6, 6): "天贶节",
    (7, 7): "七夕节",
    (7, 15): "中元节",
    (8, 15): "中秋节",
    (9, 9): "重阳节",
    (10, 1): "寒衣节",
    (10, 15): "下元节",
    (12, 8): "腊八节",
    (12, 23): "小年",
    (12, 30): "除夕",
}

# 法定节假日名称集合（用于特殊高亮标记）
LEGAL_HOLIDAY_NAMES = {
    "元旦", "春节", "清明", "劳动节", "端午", "中秋节", "国庆",
}

# 既是节气又是传统节日的
SOLAR_TERM_FESTIVALS = {"清明", "冬至"}

# 调休上班日：本来是非工作日（周末），但调为工作日 -> 显示"班"
MAKEUP_WORKDAYS = {
    # 2025
    "2025-01-26", "2025-02-08",  # 春节
    "2025-04-27",                # 五一
    "2025-05-09",                # 调休
    "2025-09-28", "2025-10-11",  # 国庆
    # 2026
    "2026-01-04",                # 元旦
    "2026-02-14", "2026-02-28",  # 春节
    "2026-05-09",                # 调休
    "2026-09-20", "2026-10-10",  # 国庆
}

# 法定节假日额外放假（非周末的工作日放假）-> 显示"休"
EXTRA_REST_DAYS = {
    # 2025 春节
    "2025-01-28", "2025-01-29", "2025-01-30", "2025-01-31",
    "2025-02-01", "2025-02-02", "2025-02-03", "2025-02-04",
    # 2025 清明
    "2025-04-04", "2025-04-05", "2025-04-06",
    # 2025 五一
    "2025-05-01", "2025-05-02", "2025-05-03", "2025-05-04", "2025-05-05",
    # 2025 端午
    "2025-05-31", "2025-06-01", "2025-06-02",
    # 2025 国庆
    "2025-10-01", "2025-10-02", "2025-10-03", "2025-10-04",
    "2025-10-05", "2025-10-06", "2025-10-07", "2025-10-08",
    # 2026 元旦
    "2026-01-01", "2026-01-02", "2026-01-03",
    # 2026 春节
    "2026-02-15", "2026-02-16", "2026-02-17", "2026-02-18", "2026-02-19",
    "2026-02-20", "2026-02-21", "2026-02-22", "2026-02-23",
    # 2026 清明
    "2026-04-04", "2026-04-05", "2026-04-06",
    # 2026 五一
    "2026-05-01", "2026-05-02", "2026-05-03", "2026-05-04", "2026-05-05",
    # 2026 端午
    "2026-06-19", "2026-06-20", "2026-06-21",
    # 2026 中秋
    "2026-09-25", "2026-09-26", "2026-09-27",
    # 2026 国庆
    "2026-10-01", "2026-10-02", "2026-10-03", "2026-10-04",
    "2026-10-05", "2026-10-06", "2026-10-07",
}


def lunar_to_text(month, day):
    """将农历月日转为中文显示"""
    if day == 1:
        return LUNAR_MONTHS[month - 1] + "月"
    return LUNAR_DAYS[day - 1]


def get_constellation(month, day):
    """按公历月日获取西方十二星座"""
    boundaries = [
        ((1, 20), "水瓶座"),
        ((2, 19), "双鱼座"),
        ((3, 21), "白羊座"),
        ((4, 20), "金牛座"),
        ((5, 21), "双子座"),
        ((6, 22), "巨蟹座"),
        ((7, 23), "狮子座"),
        ((8, 23), "处女座"),
        ((9, 23), "天秤座"),
        ((10, 24), "天蝎座"),
        ((11, 23), "射手座"),
        ((12, 22), "摩羯座"),
    ]
    constellation = "摩羯座"
    for (start_month, start_day), name in boundaries:
        if (month, day) >= (start_month, start_day):
            constellation = name
        else:
            break
    return constellation


def fetch_json(url, timeout=HTTP_TIMEOUT):
    req = urllib.request.Request(url, headers={"User-Agent": "YuranCalendar/1.0"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8"))


def weather_code_to_text(code):
    try:
        return WEATHER_CODE_TEXT.get(int(code), "未知")
    except Exception:
        return "未知"


def weather_code_to_icon(code):
    try:
        code = int(code)
    except Exception:
        return WEATHER_ICON_DEFAULT
    if code == 0:
        return "☀"
    if code in {1, 2}:
        return "◐"
    if code in {3}:
        return "☁"
    if code in {45, 48}:
        return "≋"
    if 51 <= code <= 67 or 80 <= code <= 82:
        return "☂"
    if 71 <= code <= 77 or 85 <= code <= 86:
        return "❄"
    if code >= 95:
        return "⚡"
    return WEATHER_ICON_DEFAULT


def weather_icon_color(icon, theme):
    if icon in {"☀", "◐"}:
        return "#F9A825"
    if icon == "☂":
        return "#1976D2"
    if icon == "❄":
        return "#00ACC1"
    if icon == "⚡":
        return "#F57C00"
    if icon == "≋":
        return "#78909C"
    if icon == "☁":
        return "#607D8B"
    return theme.get("fg", "#333333")


def format_temp(value):
    try:
        return str(int(round(float(value))))
    except Exception:
        return "--"


def extract_weather_temp_text(weather_info, fallback_text=""):
    if isinstance(weather_info, dict):
        temp = weather_info.get("temperature")
        if temp is not None:
            return f"{format_temp(temp)}°"
        fallback_text = weather_info.get("display", fallback_text)
    for part in str(fallback_text or "").split():
        if part.endswith("°") and "-" not in part:
            return part
    return "--°"


def extract_weather_city_text(weather_info):
    if isinstance(weather_info, dict):
        location = weather_info.get("location")
        if isinstance(location, dict):
            name = location.get("name")
        else:
            name = location
        if name:
            return short_location_name(str(name))
    return "天气"


def short_location_name(name):
    name = (name or "当前位置").strip()
    limit = 10 if name.isascii() else 6
    return name if len(name) <= limit else name[:limit]


class StickyNote:
    def __init__(self, root):
        self.root = root
        self.root.title("雨然日历")
        self.root.geometry("380x402")
        self.root.overrideredirect(True)
        self.root.attributes("-topmost", False)
        self.root.attributes("-alpha", 0.95)

        self.data = self.load_data()
        self.current_color = self.data.get("color", "yellow")
        self.custom_colors = self.data.get("custom_colors", {})
        self.reminders = self.data.get("reminders", [])
        self.schedules = self.data.get("schedules", {})
        self.show_calendar = self.data.get("show_calendar", True)
        self.weather_info = self.data.get("weather", {})
        if not isinstance(self.weather_info, dict):
            self.weather_info = {}
        self.weather_location = self.weather_info.get("location")
        self.weather_text = self.weather_info.get("display", "天气加载中")
        self.weather_icon = self.weather_info.get("icon", WEATHER_ICON_DEFAULT)
        self.weather_refreshing = False
        self.weather_prompt_open = False
        self.show_clock = self.data.get("show_clock", True)
        self.clock_style = self.data.get("clock_style", "analog")
        if self.clock_style not in ("analog", "digital"):
            self.clock_style = "analog"
        self.clock_active_style = None
        self.clock_window = None
        self.clock_canvas = None
        self.clock_container = None
        self.clock_date_label = None
        self.clock_time_label = None
        self.clock_meta_label = None
        self.clock_day_label = None
        self.clock_week_label = None
        self.clock_weather_city_label = None
        self.clock_weather_icon_label = None
        self.clock_weather_temp_label = None
        self.clock_drag_x = 0
        self.clock_drag_y = 0
        self.cal_year = datetime.now().year
        self.cal_month = datetime.now().month

        # 合并自定义颜色到 DEFAULT_COLORS
        self.all_colors = dict(DEFAULT_COLORS)
        self.all_colors.update(self.custom_colors)

        h = 582 if self.show_calendar else 402
        self.root.geometry(f"380x{h}")
        self.root.update_idletasks()
        sw = self.root.winfo_screenwidth()
        self.root.geometry(f"380x{h}+{sw - 400}+20")

        self.build_ui()
        self.apply_color()
        self.pin_to_desktop()
        self.start_reminder_thread()
        self.refresh_weather()
        if self.show_clock:
            self.root.after(200, self.show_floating_clock)
        self.root.after(1200, self.check_startup_registration)

        # 写入 pid 文件，供 bat 脚本判断是否已启动
        self._write_pid()
        self.root.protocol("WM_DELETE_WINDOW", self.on_close)

    def get_theme(self):
        """获取当前主题的颜色配置"""
        return self.all_colors.get(self.current_color, DEFAULT_COLORS["yellow"])

    def pin_to_desktop(self):
        """将窗口设为工具窗口，Win+D / 点击桌面不会隐藏"""
        try:
            self.root.wm_attributes('-toolwindow', 1)
        except Exception:
            pass

    def get_startup_command(self):
        if getattr(sys, "frozen", False):
            return f'"{sys.executable}"'
        return f'"{sys.executable}" "{os.path.abspath(__file__)}"'

    def is_startup_enabled(self):
        if sys.platform != "win32" or winreg is None:
            return True
        target = sys.executable if getattr(sys, "frozen", False) else os.path.abspath(__file__)
        try:
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, STARTUP_REG_PATH, 0, winreg.KEY_READ) as key:
                value, _ = winreg.QueryValueEx(key, STARTUP_REG_NAME)
            return os.path.normcase(target) in os.path.normcase(value)
        except FileNotFoundError:
            return False
        except OSError:
            return False

    def enable_startup(self):
        if sys.platform != "win32" or winreg is None:
            return False
        try:
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, STARTUP_REG_PATH, 0, winreg.KEY_SET_VALUE) as key:
                winreg.SetValueEx(key, STARTUP_REG_NAME, 0, winreg.REG_SZ, self.get_startup_command())
            return True
        except OSError:
            return False

    def check_startup_registration(self):
        if self.is_startup_enabled():
            return
        should_enable = messagebox.askyesno(
            "开机自启动",
            "当前未加入开机自启动，是否加入？\n\n加入后，Windows 登录时会自动启动雨然日历。",
            parent=self.root,
        )
        if not should_enable:
            return
        if self.enable_startup():
            messagebox.showinfo("开机自启动", "已加入开机自启动。", parent=self.root)
        else:
            messagebox.showwarning("开机自启动", "加入开机自启动失败，请检查系统权限。", parent=self.root)

    def build_ui(self):
        theme = self.get_theme()

        # 标题栏（可拖动）
        self.title_bar = tk.Frame(self.root, bg=theme["bg"], height=28)
        self.title_bar.pack(fill=tk.X, side=tk.TOP)
        self.title_bar.bind("<Button-1>", self.start_drag)
        self.title_bar.bind("<B1-Motion>", self.on_drag)

        # Logo（兼容开发和 PyInstaller 打包后）
        self.logo_img = None
        try:
            # PyInstaller 单文件模式下资源在 _MEIPASS 临时目录
            if getattr(sys, 'frozen', False) and hasattr(sys, '_MEIPASS'):
                logo_path = os.path.join(sys._MEIPASS, "binder-fold.png")
            else:
                logo_path = os.path.join(_app_dir(), "binder-fold.png")
            if os.path.exists(logo_path):
                pil_img = Image.open(logo_path).resize((20, 20), Image.LANCZOS)
                self.logo_img = ImageTk.PhotoImage(pil_img)
                self.logo_label = tk.Label(self.title_bar, image=self.logo_img, bg=theme["bg"])
                self.logo_label.pack(side=tk.LEFT, padx=(8, 2))
                self.logo_label.bind("<Button-1>", self.start_drag)
                self.logo_label.bind("<B1-Motion>", self.on_drag)
        except Exception:
            pass

        self.title_label = tk.Label(self.title_bar, text="雨然日历", bg=theme["bg"], fg=theme["fg"], font=("Microsoft YaHei", 10))
        self.title_label.pack(side=tk.LEFT, padx=8)
        self.title_label.bind("<Button-1>", self.start_drag)
        self.title_label.bind("<B1-Motion>", self.on_drag)

        btn_frame = tk.Frame(self.title_bar, bg=theme["bg"])
        btn_frame.pack(side=tk.RIGHT, padx=4)

        self.min_btn = tk.Label(btn_frame, text="−", bg=theme["bg"], fg="#888888", font=("Microsoft YaHei", 11), width=2, cursor="hand2")
        self.min_btn.pack(side=tk.RIGHT, padx=2)
        self.min_btn.bind("<Button-1>", lambda e: self.root.withdraw())
        self.min_btn.bind("<Enter>", lambda e: self.min_btn.config(fg=theme["fg"]))
        self.min_btn.bind("<Leave>", lambda e: self.min_btn.config(fg="#888888"))

        self.close_btn = tk.Label(btn_frame, text="×", bg=theme["bg"], fg="#888888", font=("Microsoft YaHei", 11), width=2, cursor="hand2")
        self.close_btn.pack(side=tk.RIGHT, padx=2)
        self.close_btn.bind("<Button-1>", lambda e: self.on_close())
        self.close_btn.bind("<Enter>", lambda e: self.close_btn.config(fg="#D32F2F"))
        self.close_btn.bind("<Leave>", lambda e: self.close_btn.config(fg="#888888"))

        # 今日进度提示
        self.date_info_bar = tk.Frame(self.root, bg=theme["bg"], height=22)
        self.date_info_bar.pack(fill=tk.X, side=tk.TOP)
        self.date_info_bar.pack_propagate(False)
        self.date_info_bar.bind("<Button-1>", self.start_drag)
        self.date_info_bar.bind("<B1-Motion>", self.on_drag)

        self.weather_frame = tk.Frame(self.date_info_bar, bg=theme["bg"])
        self.weather_frame.pack(side=tk.RIGHT, padx=(4, 10), pady=(0, 2))

        self.date_text_label = tk.Label(
            self.date_info_bar,
            text="",
            bg=theme["bg"],
            fg=theme.get("today", theme["fg"]),
            font=("Microsoft YaHei", 8, "bold"),
            anchor="w",
        )
        self.date_text_label.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(12, 4), pady=(0, 2))
        self.date_text_label.bind("<Button-1>", self.start_drag)
        self.date_text_label.bind("<B1-Motion>", self.on_drag)

        self.weather_icon_label = tk.Label(
            self.weather_frame,
            text=self.weather_icon,
            bg=theme["bg"],
            fg=weather_icon_color(self.weather_icon, theme),
            font=("Segoe UI Symbol", 10, "bold"),
            cursor="hand2",
        )
        self.weather_icon_label.pack(side=tk.LEFT, padx=(2, 1), pady=(0, 2))
        self.weather_icon_label.bind("<Button-1>", lambda e: self.show_weather_forecast())

        self.weather_text_label = tk.Label(
            self.weather_frame,
            text="",
            bg=theme["bg"],
            fg=theme["fg"],
            font=("Microsoft YaHei", 8, "bold"),
            anchor="w",
            cursor="hand2",
        )
        self.weather_text_label.pack(side=tk.LEFT, padx=(0, 3), pady=(0, 2))
        self.weather_text_label.bind("<Button-1>", lambda e: self.show_weather_forecast())

        self.weather_edit_label = tk.Label(
            self.weather_frame,
            text="⚙",
            bg=theme["bg"],
            fg="#1976D2",
            font=("Segoe UI Symbol", 9, "bold"),
            cursor="hand2",
        )
        self.weather_edit_label.pack(side=tk.LEFT, padx=(1, 8), pady=(0, 2))
        self.weather_edit_label.bind("<Button-1>", lambda e: self.prompt_weather_location(force=True))

        # 日历区域
        self.calendar_frame = tk.Frame(self.root)
        if self.show_calendar:
            self.calendar_frame.pack(fill=tk.X, side=tk.TOP, padx=4, pady=2)
        self.build_calendar()

        # 底部工具栏（先pack确保有空间）
        self.toolbar = tk.Frame(self.root, bg=theme["bg"])
        self.toolbar.pack(fill=tk.X, side=tk.BOTTOM)

        # 工具栏按钮：带悬停圆角效果
        def _hover_btn(parent, text, cmd, padx=6):
            btn = tk.Label(parent, text=text, bg=theme["bg"], fg=theme["fg"],
                           font=("Microsoft YaHei", 9), cursor="hand2",
                           padx=6, pady=1)
            btn.pack(side=tk.LEFT, padx=padx)
            btn.bind("<Button-1>", cmd)
            # 悬停用固定浅灰，避免主题切换后颜色不匹配
            btn.bind("<Enter>", lambda e, b=btn, obg=theme["bg"]: b.config(bg="#E0E0E0"))
            btn.bind("<Leave>", lambda e, b=btn, obg=theme["bg"]: b.config(bg=obg))
            return btn

        self.cal_btn = _hover_btn(self.toolbar, "日历", lambda e: self.toggle_calendar())
        self.theme_btn = _hover_btn(self.toolbar, "主题", lambda e: self.open_theme_dialog())
        self.color_btn = _hover_btn(self.toolbar, "颜色", self.cycle_color)
        self.clock_btn = _hover_btn(self.toolbar, "时钟", lambda e: self.toggle_clock())
        self.remind_btn = _hover_btn(self.toolbar, "+提醒", self.set_reminder)
        self.remind_count = _hover_btn(self.toolbar, f"提醒({len(self.reminders)})", lambda e: self.show_reminders(), padx=4)

        self.time_label = tk.Label(self.toolbar, text="", bg=theme["bg"], fg=theme["fg"], font=("Microsoft YaHei", 9))
        self.time_label.pack(side=tk.RIGHT, padx=6)
        self.update_time()

        # 文本编辑区（最后pack，填充剩余空间）
        self.text = tk.Text(self.root, wrap=tk.WORD, font=("Microsoft YaHei", 12), padx=10, pady=10, relief=tk.FLAT, undo=True)
        self.text.pack(fill=tk.BOTH, expand=True, padx=2, pady=2)
        self.text.insert("1.0", self.data.get("content", ""))
        self.text.bind("<KeyRelease>", lambda e: self.auto_save())

    def get_important_reminders_for_date(self, dt, lunar_year=None, lunar_month=None, lunar_day=None):
        """返回某天对应的日期型提醒；每天/每周提醒不参与红点。"""
        matched = []
        for reminder in self.reminders:
            try:
                t = reminder.get("type", "once")
                if t == "once":
                    if reminder.get("is_lunar"):
                        if lunar_month is None or lunar_day is None:
                            continue
                        same_lunar_day = (
                            lunar_month == int(reminder.get("month", 0)) and
                            lunar_day == int(reminder.get("day", 0))
                        )
                        if same_lunar_day and (
                            lunar_year is None or
                            int(reminder.get("year", lunar_year)) == lunar_year
                        ):
                            matched.append(reminder)
                    elif (
                        dt.year == int(reminder.get("year", 0)) and
                        dt.month == int(reminder.get("month", 0)) and
                        dt.day == int(reminder.get("day", 0))
                    ):
                        matched.append(reminder)
                elif t == "monthly":
                    if dt.day == int(reminder.get("day", 0)):
                        matched.append(reminder)
                elif t == "yearly":
                    if (
                        dt.month == int(reminder.get("month", 0)) and
                        dt.day == int(reminder.get("day", 0))
                    ):
                        matched.append(reminder)
                elif t == "lunar_yearly":
                    if (
                        lunar_month == int(reminder.get("lunar_month", 0)) and
                        lunar_day == int(reminder.get("lunar_day", 0))
                    ):
                        matched.append(reminder)
                elif t == "lunar_monthly":
                    if lunar_day == int(reminder.get("lunar_day", 0)):
                        matched.append(reminder)
            except Exception:
                continue
        return matched

    def has_important_reminder(self, dt, lunar_year=None, lunar_month=None, lunar_day=None):
        return bool(self.get_important_reminders_for_date(dt, lunar_year, lunar_month, lunar_day))

    def build_calendar(self):
        theme = self.get_theme()
        for w in self.calendar_frame.winfo_children():
            w.destroy()

        self.calendar_frame.config(bg=theme["bg"])
        today = datetime.now()
        cell_w, cell_h = 48, 58

        # 年月导航 - 更美观的圆角按钮
        nav = tk.Frame(self.calendar_frame, bg=theme["bg"])
        nav.pack(fill=tk.X, pady=(2, 4))

        def _nav_btn(parent, text, cmd):
            lbl = tk.Label(parent, text=text, bg=theme.get("weekend", "#EEEEEE"), fg=theme["fg"],
                           font=("Microsoft YaHei", 10, "bold"), cursor="hand2",
                           padx=8, pady=1)
            lbl.pack(side=tk.LEFT, padx=4)
            lbl.bind("<Button-1>", cmd)
            lbl.bind("<Enter>", lambda e, l=lbl: l.config(bg=theme.get("today", "#FF9800"), fg="#FFFFFF"))
            lbl.bind("<Leave>", lambda e, l=lbl: l.config(bg=theme.get("weekend", "#EEEEEE"), fg=theme["fg"]))
            return lbl

        _nav_btn(nav, "◀", lambda e: self.change_month(-1))

        self.cal_title = tk.Label(nav, text=f"{self.cal_year}年{self.cal_month}月",
                                   bg=theme["bg"], fg=theme["fg"],
                                   font=("Microsoft YaHei", 11, "bold"))
        self.cal_title.pack(side=tk.LEFT, expand=True)

        _nav_btn(nav, "▶", lambda e: self.change_month(1))

        # 星期标题 - 带分隔线
        header = tk.Frame(self.calendar_frame, bg=theme["bg"])
        header.pack(fill=tk.X, pady=(0, 2))
        for i, d in enumerate(WEEKDAYS_SHORT):
            fg_color = theme.get("holiday", "#E53935") if i >= 5 else theme["fg"]
            lbl = tk.Label(header, text=d, bg=theme["bg"], fg=fg_color,
                           font=("Microsoft YaHei", 9, "bold"))
            lbl.pack(side=tk.LEFT, expand=True)
            lbl.config(width=4)

        # 日期网格
        grid = tk.Frame(self.calendar_frame, bg=theme["bg"])
        grid.pack(fill=tk.X)

        first_day = datetime(self.cal_year, self.cal_month, 1)
        weekday = first_day.weekday()
        days_in_month = (datetime(self.cal_year + 1, 1, 1) if self.cal_month == 12 else datetime(self.cal_year, self.cal_month + 1, 1)) - first_day
        total_days = days_in_month.days

        # 填充空白
        for _ in range(weekday):
            blank = tk.Frame(grid, bg=theme["bg"], width=cell_w, height=cell_h)
            blank.pack_propagate(False)
            blank.pack(side=tk.LEFT, padx=1, pady=1)

        day_count = 0
        for day in range(1, total_days + 1):
            dt = datetime(self.cal_year, self.cal_month, day)
            is_today = (dt.year == today.year and dt.month == today.month and dt.day == today.day)
            is_weekend = dt.weekday() >= 5

            # 获取农历和节气（优先用 cnlunar）
            lunar_text = ""
            jieqi = ""
            holiday = ""

            lunar_month_num = None
            lunar_day_num = None
            lunar_year_num = None

            if CNLUNAR_OK:
                try:
                    lunar_obj = cnlunar.Lunar(dt)
                    # 尝试获取数字形式的农历月日，并用 lunar_to_text 格式化（初一显示月份）
                    try:
                        lunar_year_num = int(lunar_obj.lunarYear)
                        lunar_month_num = int(lunar_obj.lunarMonth)
                        lunar_day_num = int(lunar_obj.lunarDay)
                        lunar_text = lunar_to_text(lunar_month_num, lunar_day_num)
                    except Exception:
                        lunar_text = lunar_obj.lunarDayCn
                    jq = lunar_obj.todaySolarTerms
                    if jq and jq != "无":
                        jieqi = jq
                except Exception:
                    pass
            elif ZHDATE_OK:
                try:
                    lunar = ZhDate.from_datetime(dt)
                    lunar_text = lunar_to_text(lunar.lunar_month, lunar.lunar_day)
                    lunar_year_num = lunar.lunar_year
                    lunar_month_num = lunar.lunar_month
                    lunar_day_num = lunar.lunar_day
                except Exception:
                    pass

            # 统一计算农历节日
            if lunar_month_num is not None and lunar_day_num is not None:
                holiday = LUNAR_HOLIDAYS.get((lunar_month_num, lunar_day_num), "")

            if not holiday:
                holiday = SOLAR_HOLIDAYS.get((self.cal_month, day), "")

            # 节气中的传统节日（清明、冬至）按节日显示
            if jieqi and jieqi in SOLAR_TERM_FESTIVALS:
                holiday = jieqi
                jieqi = ""

            # 判断是否为法定节假日
            is_legal_holiday = any(name in holiday for name in LEGAL_HOLIDAY_NAMES)

            # 背景色
            if is_today:
                bg = theme.get("today", "#FF9800")
                day_fg = "#FFFFFF"
            elif is_weekend:
                bg = theme.get("weekend", "#FFE0B2")
                day_fg = theme["fg"]
            else:
                bg = theme["bg"]
                day_fg = theme["fg"]

            date_key = f"{self.cal_year:04d}-{self.cal_month:02d}-{day:02d}"
            has_schedule = date_key in self.schedules and self.schedules[date_key]
            has_reminder = self.has_important_reminder(dt, lunar_year_num, lunar_month_num, lunar_day_num)

            # 调休/休息标记
            day_tag = None
            if date_key in MAKEUP_WORKDAYS:
                day_tag = "班"
            elif is_weekend or date_key in EXTRA_REST_DAYS:
                day_tag = "休"

            # 单元格：今日加边框
            today_border = "#E65100" if is_today else bg
            cell = tk.Frame(grid, bg=bg, width=cell_w, height=cell_h,
                            highlightbackground=today_border,
                            highlightthickness=(2 if is_today else 0))
            cell.pack_propagate(False)
            cell.pack(side=tk.LEFT, padx=2, pady=2)

            def bind_date_widget(widget, y=self.cal_year, m=self.cal_month, d=day, marked=has_reminder):
                widget.bind("<Button-3>", lambda e, yy=y, mm=m, dd=d: self.show_date_menu(e, yy, mm, dd))
                if marked:
                    widget.bind("<Button-1>", lambda e, yy=y, mm=m, dd=d: self.show_date_reminders(yy, mm, dd))
                    try:
                        widget.config(cursor="hand2")
                    except Exception:
                        pass

            bind_date_widget(cell)

            # 公历日期 + 调休标记（带背景色圆角效果）
            day_frame = tk.Frame(cell, bg=bg)
            day_frame.pack(pady=(2, 0))
            bind_date_widget(day_frame)
            day_lbl = tk.Label(day_frame, text=str(day), bg=bg, fg=day_fg, font=("Microsoft YaHei", 10, "bold"))
            day_lbl.pack(side=tk.LEFT)
            bind_date_widget(day_lbl)
            if has_reminder:
                dot = tk.Canvas(day_frame, width=8, height=8, bg=bg, highlightthickness=0, bd=0)
                dot.create_oval(1, 1, 7, 7, fill="#E53935", outline="#FFFFFF" if is_today else "")
                dot.pack(side=tk.LEFT, padx=(2, 0), pady=(1, 0))
                bind_date_widget(dot)
            if day_tag:
                tag_bg = "#D32F2F" if day_tag == "班" else "#2E7D32"
                tag_lbl = tk.Label(day_frame, text=day_tag, bg=tag_bg, fg="#FFFFFF",
                                   font=("Microsoft YaHei", 7, "bold"),
                                   padx=2, pady=0)
                tag_lbl.pack(side=tk.LEFT, padx=(2, 0))
                bind_date_widget(tag_lbl)

            # 第二行：节气（绿色）或节假日（红色）或日程标记
            line2_text = ""
            line2_fg = ""
            if holiday:
                line2_text = holiday
                line2_fg = theme.get("holiday", "#D32F2F")
                if is_legal_holiday:
                    line2_fg = "#C62828"  # 法定节假日用更深的红色
            elif jieqi:
                line2_text = jieqi
                line2_fg = "#2E7D32"
            elif has_schedule:
                line2_text = "·日程"
                line2_fg = theme.get("today", "#FF9800")

            if line2_text:
                line2_font = ("Microsoft YaHei", 7, "bold")
                if is_legal_holiday:
                    line2_font = ("Microsoft YaHei", 8, "bold")
                line2_lbl = tk.Label(cell, text=line2_text, bg=bg, fg=line2_fg, font=line2_font)
                line2_lbl.pack()
                bind_date_widget(line2_lbl)
            else:
                line2_blank = tk.Label(cell, text="", bg=bg, font=("Microsoft YaHei", 7))
                line2_blank.pack()
                bind_date_widget(line2_blank)

            # 第三行：农历（用主题文字色，更明显）
            if lunar_text:
                lunar_fg = theme["fg"]
                sub = tk.Label(cell, text=lunar_text, bg=bg, fg=lunar_fg, font=("Microsoft YaHei", 8))
                sub.pack()
                bind_date_widget(sub)
            else:
                sub_blank = tk.Label(cell, text="", bg=bg, font=("Microsoft YaHei", 8))
                sub_blank.pack()
                bind_date_widget(sub_blank)

            day_count += 1
            if (weekday + day_count) % 7 == 0:
                grid = tk.Frame(self.calendar_frame, bg=theme["bg"])
                grid.pack(fill=tk.X)

    def change_month(self, delta):
        self.cal_month += delta
        if self.cal_month > 12:
            self.cal_month = 1
            self.cal_year += 1
        elif self.cal_month < 1:
            self.cal_month = 12
            self.cal_year -= 1
        self.build_calendar()

    def get_lunar_parts_for_date(self, dt):
        if CNLUNAR_OK:
            try:
                lunar = cnlunar.Lunar(dt)
                return int(lunar.lunarYear), int(lunar.lunarMonth), int(lunar.lunarDay)
            except Exception:
                return None, None, None
        if ZHDATE_OK:
            try:
                lunar = ZhDate.from_datetime(dt)
                return lunar.lunar_year, lunar.lunar_month, lunar.lunar_day
            except Exception:
                return None, None, None
        return None, None, None

    def format_date_reminder_type(self, reminder):
        t = reminder.get("type", "once")
        if t == "once":
            return "农历单次" if reminder.get("is_lunar") else "单次"
        if t == "monthly":
            return "每月"
        if t == "yearly":
            return "每年"
        if t == "lunar_yearly":
            return "每年农历"
        if t == "lunar_monthly":
            return "每月农历"
        return "提醒"

    def show_date_reminders(self, year, month, day):
        dt = datetime(year, month, day)
        lunar_year, lunar_month, lunar_day = self.get_lunar_parts_for_date(dt)
        reminders = self.get_important_reminders_for_date(dt, lunar_year, lunar_month, lunar_day)
        if not reminders:
            return

        dialog = tk.Toplevel(self.root)
        dialog.title("当天提醒")
        dialog.transient(self.root)
        dialog.grab_set()
        dialog.attributes("-topmost", True)
        dialog.resizable(False, False)

        x = self.root.winfo_x() + 28
        y = self.root.winfo_y() + 58
        height = min(420, 130 + len(reminders) * 72)
        dialog.geometry(f"340x{height}+{x}+{y}")

        bg = "#FFFFFF"
        panel = "#FFF5F5"
        accent = "#E53935"
        text_fg = "#263238"
        muted = "#78909C"
        dialog.config(bg=bg)

        title = f"{year}年{month}月{day}日"
        tk.Label(dialog, text=title, bg=bg, fg=text_fg,
                 font=("Microsoft YaHei", 13, "bold")).pack(pady=(14, 2))
        tk.Label(dialog, text=f"共 {len(reminders)} 条提醒", bg=bg, fg=accent,
                 font=("Microsoft YaHei", 9, "bold")).pack(pady=(0, 8))

        list_frame = tk.Frame(dialog, bg=bg)
        list_frame.pack(fill=tk.BOTH, expand=True, padx=14)

        for reminder in reminders:
            row = tk.Frame(list_frame, bg=panel, highlightbackground="#F3B7B7", highlightthickness=1)
            row.pack(fill=tk.X, pady=4)

            bar = tk.Frame(row, bg=accent, width=4)
            bar.pack(side=tk.LEFT, fill=tk.Y)

            body = tk.Frame(row, bg=panel)
            body.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=9, pady=7)

            hour = int(reminder.get("hour", 0))
            minute = int(reminder.get("minute", 0))
            kind = self.format_date_reminder_type(reminder)
            tk.Label(body, text=f"{kind}  {hour:02d}:{minute:02d}",
                     bg=panel, fg=muted, font=("Microsoft YaHei", 9, "bold"),
                     anchor="w").pack(fill=tk.X)
            tk.Label(body, text=reminder.get("message", ""),
                     bg=panel, fg=text_fg, font=("Microsoft YaHei", 11),
                     anchor="w", justify=tk.LEFT, wraplength=280).pack(fill=tk.X, pady=(3, 0))

        btn = tk.Label(dialog, text="关闭", bg=accent, fg="#FFFFFF",
                       font=("Microsoft YaHei", 10, "bold"),
                       padx=18, pady=4, cursor="hand2")
        btn.pack(pady=(8, 12))
        btn.bind("<Button-1>", lambda e: dialog.destroy())

    def show_date_menu(self, event, year, month, day):
        """在日期单元格上右键弹出菜单"""
        menu = tk.Menu(self.root, tearoff=0)
        date_str = f"{year}年{month}月{day}日"
        menu.add_command(label=date_str, state="disabled")
        menu.add_separator()
        menu.add_command(label="添加提醒", command=lambda: self.set_reminder(prefill=(year, month, day)))
        menu.add_command(label="添加日程", command=lambda: self.add_schedule(year, month, day))

        date_key = f"{year:04d}-{month:02d}-{day:02d}"
        if date_key in self.schedules and self.schedules[date_key]:
            menu.add_separator()
            menu.add_command(label="已有日程:", state="disabled")
            for item in self.schedules[date_key]:
                menu.add_command(label=f"  · {item}", state="disabled")

        menu.tk_popup(event.x_root, event.y_root)

    def toggle_calendar(self):
        self.show_calendar = not self.show_calendar
        if self.show_calendar:
            # 用 before=toolbar 确保日历插在工具栏之前
            self.calendar_frame.pack(fill=tk.X, side=tk.TOP, padx=4, pady=2, before=self.toolbar)
            self.root.geometry("380x582")
        else:
            self.calendar_frame.pack_forget()
            self.root.geometry("380x402")
        self.auto_save()

    def apply_color(self):
        theme = self.get_theme()
        for widget in [self.title_bar, self.date_info_bar, self.weather_frame, self.toolbar, self.calendar_frame]:
            widget.config(bg=theme["bg"])
        for widget in [self.title_label, self.close_btn, self.min_btn, self.cal_btn, self.theme_btn,
                       self.clock_btn,
                       self.color_btn, self.remind_btn, self.remind_count, self.time_label]:
            widget.config(bg=theme["bg"], fg=theme["fg"])
        self.date_text_label.config(bg=theme["bg"], fg=theme.get("today", theme["fg"]))
        self.weather_icon_label.config(bg=theme["bg"], fg=weather_icon_color(self.weather_icon, theme))
        self.weather_text_label.config(bg=theme["bg"], fg=theme["fg"])
        self.weather_edit_label.config(bg=theme["bg"], fg="#1976D2")
        self.text.config(bg=theme["bg"], foreground=theme["fg"], insertbackground=theme["fg"])
        self.build_calendar()
        self.apply_clock_theme()

    def cycle_color(self, event=None):
        colors = list(self.all_colors.keys())
        idx = colors.index(self.current_color)
        self.current_color = colors[(idx + 1) % len(colors)]
        self.apply_color()
        self.auto_save()

    def toggle_clock(self, event=None):
        self.show_clock_menu(event)

    def show_clock_menu(self, event=None):
        menu = tk.Menu(self.root, tearoff=0, font=("Microsoft YaHei", 10))
        analog_mark = "✓ " if self.show_clock and self.clock_style == "analog" else ""
        digital_mark = "✓ " if self.show_clock and self.clock_style == "digital" else ""
        menu.add_command(label=f"{analog_mark}圆形时钟", command=lambda: self.select_clock_style("analog"))
        menu.add_command(label=f"{digital_mark}数字时钟", command=lambda: self.select_clock_style("digital"))
        menu.add_separator()
        menu.add_command(label="关闭时钟", command=self.hide_floating_clock)

        try:
            if event is not None:
                x, y = event.x_root, event.y_root
            else:
                x = self.clock_btn.winfo_rootx()
                y = self.clock_btn.winfo_rooty() + self.clock_btn.winfo_height()
            menu.tk_popup(x, y)
        finally:
            menu.grab_release()

    def select_clock_style(self, style):
        if style not in ("analog", "digital"):
            return
        self.clock_style = style
        self.data["clock_style"] = style
        if self.clock_window is not None and self.clock_window.winfo_exists():
            self.save_clock_position()
            self.clock_window.destroy()
            self.clock_window = None
        self.show_floating_clock(style)

    def get_clock_position(self, w, h):
        sw = self.root.winfo_screenwidth()
        sh = self.root.winfo_screenheight()
        margin = 16
        pos = self.data.get("clock_position", {})
        try:
            x = int(pos.get("x"))
            y = int(pos.get("y"))
        except Exception:
            x = sw - w - 28
            y = 92
        max_x = max(margin, sw - w - margin)
        max_y = max(margin, sh - h - margin)
        return min(max(x, margin), max_x), min(max(y, margin), max_y)

    def show_floating_clock(self, style=None):
        if style in ("analog", "digital"):
            self.clock_style = style
        if self.clock_style not in ("analog", "digital"):
            self.clock_style = "analog"

        if self.clock_window is not None and self.clock_window.winfo_exists():
            if self.clock_active_style == self.clock_style:
                self.clock_window.lift()
                return
            self.save_clock_position()
            self.clock_window.destroy()
            self.clock_window = None

        self.show_clock = True
        self.clock_active_style = self.clock_style
        self.data["clock_style"] = self.clock_style
        self.clock_canvas = None
        self.clock_container = None
        self.clock_date_label = None
        self.clock_time_label = None
        self.clock_meta_label = None
        self.clock_day_label = None
        self.clock_week_label = None
        self.clock_weather_city_label = None
        self.clock_weather_icon_label = None
        self.clock_weather_temp_label = None

        self.clock_window = tk.Toplevel(self.root)
        self.clock_window.overrideredirect(True)
        self.clock_window.attributes("-topmost", False)

        if self.clock_style == "analog":
            mask_bg = "#010203"
            self.clock_window.configure(bg=mask_bg)
            try:
                self.clock_window.attributes("-alpha", 0.78)
                self.clock_window.wm_attributes("-transparentcolor", mask_bg)
                self.clock_window.wm_attributes("-toolwindow", 1)
            except Exception:
                pass

            w = h = 236
            x, y = self.get_clock_position(w, h)
            self.clock_window.geometry(f"{w}x{h}+{x}+{y}")

            self.clock_mask_bg = mask_bg
            self.clock_size = w
            self.clock_canvas = tk.Canvas(
                self.clock_window,
                width=w,
                height=h,
                bg=mask_bg,
                highlightthickness=0,
                bd=0,
                cursor="fleur",
            )
            self.clock_canvas.pack(fill=tk.BOTH, expand=True)
            drag_widgets = [self.clock_window, self.clock_canvas]
        else:
            panel_bg = "#071017"
            panel_mid = "#101B24"
            border = "#7F93A6"
            text_main = "#FAFCFF"
            text_date = "#DDE6EE"
            text_meta = "#8FD9BA"
            try:
                self.clock_window.attributes("-alpha", 0.88)
                self.clock_window.wm_attributes("-toolwindow", 1)
            except Exception:
                pass

            w, h = 400, 72
            x, y = self.get_clock_position(w, h)
            self.clock_window.configure(bg=panel_bg)
            self.clock_window.geometry(f"{w}x{h}+{x}+{y}")

            self.clock_container = tk.Frame(
                self.clock_window,
                bg=panel_bg,
                highlightbackground=border,
                highlightthickness=1,
                cursor="fleur",
            )
            self.clock_container.pack(fill=tk.BOTH, expand=True)

            main = tk.Frame(self.clock_container, bg=panel_bg, cursor="fleur")
            main.pack(fill=tk.BOTH, expand=True, padx=(12, 10), pady=(6, 6))
            clock_now = datetime.now()

            self.clock_time_label = tk.Label(
                main,
                text=clock_now.strftime("%H:%M"),
                bg=panel_bg,
                fg=text_main,
                font=("Segoe UI", 27, "bold"),
                anchor="w",
                cursor="fleur",
            )
            self.clock_time_label.pack(side=tk.LEFT, padx=(0, 10), pady=(0, 1))

            divider = tk.Frame(main, bg="#7F93A6", width=1, height=42, cursor="fleur")
            divider.pack(side=tk.LEFT, padx=(0, 10), pady=(9, 9))
            divider.pack_propagate(False)

            info = tk.Frame(main, bg=panel_bg, width=132, cursor="fleur")
            info.pack(side=tk.LEFT, fill=tk.Y, pady=(7, 6))
            info.pack_propagate(False)

            self.clock_date_label = tk.Label(
                info,
                text=f"{clock_now.month}月{clock_now.day}日 {WEEKDAYS[clock_now.weekday()]}",
                bg=panel_bg,
                fg=text_date,
                font=("Microsoft YaHei UI", 11, "bold"),
                anchor="w",
                cursor="fleur",
            )
            self.clock_date_label.pack(fill=tk.X, pady=(0, 6))

            meta = tk.Frame(info, bg=panel_bg, cursor="fleur")
            meta.pack(fill=tk.X)
            self.clock_day_label = tk.Label(
                meta,
                text=f"第{clock_now.timetuple().tm_yday}天",
                bg=panel_bg,
                fg=text_meta,
                font=("Microsoft YaHei UI", 9),
                anchor="w",
                cursor="fleur",
            )
            self.clock_day_label.pack(side=tk.LEFT, padx=(0, 10))

            self.clock_week_label = tk.Label(
                meta,
                text=f"第{clock_now.isocalendar().week}周",
                bg=panel_bg,
                fg=text_meta,
                font=("Microsoft YaHei UI", 9, "bold"),
                anchor="w",
                cursor="fleur",
            )
            self.clock_week_label.pack(side=tk.LEFT)

            weather = tk.Frame(main, bg=panel_mid, width=132, height=42, cursor="fleur")
            weather.pack(side=tk.LEFT, padx=(8, 0), pady=(9, 9))
            weather.pack_propagate(False)

            self.clock_weather_city_label = tk.Label(
                weather,
                text=extract_weather_city_text(self.weather_info),
                bg=panel_mid,
                fg="#B9C7D4",
                font=("Microsoft YaHei UI", 9, "bold"),
                anchor="center",
                cursor="fleur",
            )
            self.clock_weather_city_label.pack(side=tk.LEFT, fill=tk.Y, padx=(8, 4))

            self.clock_weather_icon_label = tk.Label(
                weather,
                text=self.weather_icon or WEATHER_ICON_DEFAULT,
                bg=panel_mid,
                fg=weather_icon_color(self.weather_icon, self.get_theme()),
                font=("Segoe UI Symbol", 15, "bold"),
                anchor="center",
                cursor="fleur",
            )
            self.clock_weather_icon_label.pack(side=tk.LEFT, fill=tk.Y, padx=(0, 4))

            self.clock_weather_temp_label = tk.Label(
                weather,
                text=extract_weather_temp_text(self.weather_info, self.weather_text),
                bg=panel_mid,
                fg=text_date,
                font=("Segoe UI", 10, "bold"),
                anchor="center",
                cursor="fleur",
            )
            self.clock_weather_temp_label.pack(side=tk.LEFT, fill=tk.Y, padx=(0, 8))

            self.clock_meta_label = tk.Label(
                main,
                text="",
                bg=panel_bg,
            )
            drag_widgets = [self.clock_window, self.clock_container, main,
                            divider, info, meta, weather,
                            self.clock_time_label, self.clock_date_label,
                            self.clock_day_label, self.clock_week_label,
                            self.clock_weather_city_label, self.clock_weather_icon_label,
                            self.clock_weather_temp_label]

        for widget in drag_widgets:
            widget.bind("<Button-1>", self.start_clock_drag)
            widget.bind("<B1-Motion>", self.on_clock_drag)
            widget.bind("<ButtonRelease-1>", self.save_clock_position)

        self.update_clock_button()
        self.update_floating_clock()
        self.clock_window.update_idletasks()
        self.auto_save()

    def hide_floating_clock(self):
        if self.clock_window is not None and self.clock_window.winfo_exists():
            self.save_clock_position()
            self.clock_window.destroy()
        self.clock_window = None
        self.clock_active_style = None
        self.clock_canvas = None
        self.clock_container = None
        self.clock_date_label = None
        self.clock_time_label = None
        self.clock_meta_label = None
        self.clock_day_label = None
        self.clock_week_label = None
        self.clock_weather_city_label = None
        self.clock_weather_icon_label = None
        self.clock_weather_temp_label = None
        self.show_clock = False
        self.update_clock_button()
        self.auto_save()

    def apply_clock_theme(self):
        if self.clock_window is None or not self.clock_window.winfo_exists():
            self.update_clock_button()
            return
        if self.clock_active_style == "analog":
            self.draw_analog_clock()
        elif self.clock_active_style == "digital" and self.clock_time_label is not None:
            if self.clock_container is not None:
                self.clock_container.config(bg="#071017", highlightbackground="#7F93A6")
            for widget in [
                self.clock_time_label,
                self.clock_date_label,
                self.clock_day_label,
                self.clock_week_label,
            ]:
                if widget is not None:
                    widget.config(bg="#071017")
            if self.clock_time_label is not None:
                self.clock_time_label.config(fg="#FAFCFF")
            if self.clock_date_label is not None:
                self.clock_date_label.config(fg="#DDE6EE")
            if self.clock_day_label is not None:
                self.clock_day_label.config(fg="#8FD9BA")
            if self.clock_week_label is not None:
                self.clock_week_label.config(fg="#8FD9BA")
            if self.clock_weather_icon_label is not None:
                self.clock_weather_icon_label.config(
                    bg="#101B24",
                    fg=weather_icon_color(self.weather_icon, self.get_theme()),
                )
            if self.clock_weather_city_label is not None:
                self.clock_weather_city_label.config(bg="#101B24", fg="#B9C7D4")
            if self.clock_weather_temp_label is not None:
                self.clock_weather_temp_label.config(bg="#101B24", fg="#DDE6EE")
        self.update_clock_button()

    def clock_point(self, cx, cy, degrees, length):
        angle = math.radians(degrees - 90)
        return cx + math.cos(angle) * length, cy + math.sin(angle) * length

    def draw_analog_clock(self, now=None):
        if not hasattr(self, "clock_canvas") or self.clock_canvas is None:
            return
        if self.clock_window is None or not self.clock_window.winfo_exists():
            return

        now = now or datetime.now()
        canvas = self.clock_canvas
        canvas.delete("all")

        theme = self.get_theme()
        accent = theme.get("today", "#FF9800")
        size = self.clock_size if hasattr(self, "clock_size") else 236
        cx = cy = size / 2
        radius = size / 2 - 13
        face_bg = "#121C27"
        ring = "#2A3A4C"
        inner_ring = "#1E2C3A"
        tick_color = "#D8E2EA"
        muted = "#8EA0AF"
        text_color = "#F8FAFC"

        canvas.create_oval(cx - radius + 3, cy - radius + 5, cx + radius + 3, cy + radius + 5,
                           fill="#050A10", outline="")
        canvas.create_oval(cx - radius, cy - radius, cx + radius, cy + radius,
                           fill=face_bg, outline=ring, width=2)
        canvas.create_oval(cx - radius + 9, cy - radius + 9, cx + radius - 9, cy + radius - 9,
                           outline=inner_ring, width=1)

        for i in range(60):
            degrees = i * 6
            is_hour = i % 5 == 0
            outer = radius - 13
            inner = outer - (11 if is_hour else 5)
            x1, y1 = self.clock_point(cx, cy, degrees, inner)
            x2, y2 = self.clock_point(cx, cy, degrees, outer)
            canvas.create_line(
                x1, y1, x2, y2,
                fill=tick_color if is_hour else "#526273",
                width=3 if is_hour else 1,
            )

        for text, degrees in [("12", 0), ("3", 90), ("6", 180), ("9", 270)]:
            x, y = self.clock_point(cx, cy, degrees, radius - 36)
            canvas.create_text(x, y, text=text, fill=muted, font=("Segoe UI", 10, "bold"))

        hour_degrees = ((now.hour % 12) + now.minute / 60) * 30
        minute_degrees = (now.minute + now.second / 60) * 6
        second_degrees = now.second * 6

        hx, hy = self.clock_point(cx, cy, hour_degrees, radius * 0.43)
        mx, my = self.clock_point(cx, cy, minute_degrees, radius * 0.64)
        sx, sy = self.clock_point(cx, cy, second_degrees, radius * 0.73)
        tx, ty = self.clock_point(cx, cy, second_degrees + 180, radius * 0.15)

        canvas.create_line(cx, cy, hx, hy, fill="#F5F8FB", width=6)
        canvas.create_line(cx, cy, mx, my, fill="#C9D4DF", width=4)
        canvas.create_line(tx, ty, sx, sy, fill=accent, width=2)

        badge_w = 92
        badge_h = 50
        canvas.create_oval(cx - 8, cy - 8, cx + 8, cy + 8, fill=accent, outline="")
        canvas.create_oval(cx - badge_w / 2, cy - badge_h / 2, cx + badge_w / 2, cy + badge_h / 2,
                           fill="#172332", outline="#314256", width=1)
        canvas.create_text(cx, cy - 9, text=now.strftime("%m月%d日"), fill=text_color,
                           font=("Microsoft YaHei UI", 13, "bold"))
        canvas.create_text(cx, cy + 14, text=WEEKDAYS[now.weekday()], fill=accent,
                           font=("Microsoft YaHei UI", 11, "bold"))

    def update_clock_button(self):
        if not hasattr(self, "clock_btn"):
            return
        theme = self.get_theme()
        self.clock_btn.config(fg=theme.get("today", theme["fg"]) if self.show_clock else theme["fg"])

    def start_clock_drag(self, event):
        if self.clock_window is None or not self.clock_window.winfo_exists():
            return
        self.clock_drag_x = event.x_root - self.clock_window.winfo_x()
        self.clock_drag_y = event.y_root - self.clock_window.winfo_y()

    def on_clock_drag(self, event):
        if self.clock_window is None or not self.clock_window.winfo_exists():
            return
        x = event.x_root - self.clock_drag_x
        y = event.y_root - self.clock_drag_y
        self.clock_window.geometry(f"+{x}+{y}")

    def save_clock_position(self, event=None):
        if self.clock_window is None or not self.clock_window.winfo_exists():
            return
        self.data["clock_position"] = {
            "x": self.clock_window.winfo_x(),
            "y": self.clock_window.winfo_y(),
        }
        self.data["show_clock"] = self.show_clock
        self.data["clock_style"] = self.clock_style
        self.save_data()

    def update_floating_clock(self):
        try:
            if self.clock_window is None or not self.clock_window.winfo_exists():
                return
            now = datetime.now()
            if self.clock_active_style == "analog":
                self.draw_analog_clock(now)
            elif self.clock_active_style == "digital":
                if self.clock_date_label is not None:
                    self.clock_date_label.config(text=f"{now.month}月{now.day}日 {WEEKDAYS[now.weekday()]}")
                if self.clock_time_label is not None:
                    self.clock_time_label.config(text=now.strftime("%H:%M"))
                if self.clock_day_label is not None:
                    self.clock_day_label.config(text=f"第{now.timetuple().tm_yday}天")
                if self.clock_week_label is not None:
                    self.clock_week_label.config(text=f"第{now.isocalendar().week}周")
                if self.clock_weather_icon_label is not None:
                    self.clock_weather_icon_label.config(
                        text=self.weather_icon or WEATHER_ICON_DEFAULT,
                        fg=weather_icon_color(self.weather_icon, self.get_theme()),
                    )
                if self.clock_weather_city_label is not None:
                    self.clock_weather_city_label.config(text=extract_weather_city_text(self.weather_info))
                if self.clock_weather_temp_label is not None:
                    self.clock_weather_temp_label.config(
                        text=extract_weather_temp_text(self.weather_info, self.weather_text)
                    )
            self.clock_window.after(1000, self.update_floating_clock)
        except Exception:
            if self.clock_window is not None and self.clock_window.winfo_exists():
                self.clock_window.after(1000, self.update_floating_clock)

    def open_theme_dialog(self):
        """打开主题配置对话框"""
        dialog = tk.Toplevel(self.root)
        dialog.title("主题设置")
        dialog.transient(self.root)
        dialog.grab_set()
        dialog.attributes("-topmost", True)

        x = self.root.winfo_x() + 20
        y = self.root.winfo_y() + 40
        dialog.geometry(f"320x420+{x}+{y}")
        dialog.resizable(False, False)

        theme = self.get_theme()

        # 当前颜色值
        colors = {
            "bg": ("背景色", theme["bg"]),
            "fg": ("文字色", theme["fg"]),
            "today": ("今天高亮色", theme["today"]),
            "holiday": ("节假日颜色", theme["holiday"]),
            "weekend": ("周末背景色", theme["weekend"]),
        }

        color_vars = {}
        preview_labels = {}

        tk.Label(dialog, text="自定义颜色", font=("Microsoft YaHei", 12, "bold")).pack(pady=(10, 5))

        for key, (label, default) in colors.items():
            frame = tk.Frame(dialog)
            frame.pack(fill=tk.X, padx=20, pady=4)

            tk.Label(frame, text=label, font=("Microsoft YaHei", 10), width=10, anchor="w").pack(side=tk.LEFT)

            var = tk.StringVar(value=default)
            color_vars[key] = var

            entry = tk.Entry(frame, textvariable=var, font=("Microsoft YaHei", 10), width=10)
            entry.pack(side=tk.LEFT, padx=4)

            preview = tk.Label(frame, text="  ", bg=default, width=3, relief="solid")
            preview.pack(side=tk.LEFT, padx=4)
            preview_labels[key] = preview

            def pick_color(k=key, v=var, p=preview):
                c = colorchooser.askcolor(color=v.get(), title=f"选择颜色")[1]
                if c:
                    v.set(c.upper())
                    p.config(bg=c)
                    self._preview_theme(color_vars)

            tk.Button(frame, text="选色", command=pick_color, font=("Microsoft YaHei", 9)).pack(side=tk.LEFT)

        # 实时预览区域
        preview_frame = tk.Frame(dialog, relief="solid", bd=1)
        preview_frame.pack(fill=tk.X, padx=20, pady=10, ipady=10)

        self.preview_title = tk.Label(preview_frame, text="便签预览", font=("Microsoft YaHei", 10))
        self.preview_title.pack()

        self.preview_text = tk.Label(preview_frame, text="今天: 22\n周末: 23", font=("Microsoft YaHei", 9))
        self.preview_text.pack()

        # 预设主题
        tk.Label(dialog, text="预设主题", font=("Microsoft YaHei", 10)).pack(pady=(5, 2))

        preset_frame = tk.Frame(dialog)
        preset_frame.pack(pady=2)

        for name in DEFAULT_COLORS:
            c = DEFAULT_COLORS[name]["bg"]
            btn = tk.Label(preset_frame, text=name, bg=c, fg=DEFAULT_COLORS[name]["fg"],
                           font=("Microsoft YaHei", 9), width=6, relief="solid", cursor="hand2")
            btn.pack(side=tk.LEFT, padx=2)
            btn.bind("<Button-1>", lambda e, n=name: self._apply_preset(n, color_vars, preview_labels))

        # 保存 / 取消
        btn_frame = tk.Frame(dialog)
        btn_frame.pack(pady=15)

        def save_theme():
            custom = {key: var.get() for key, var in color_vars.items()}
            # 生成主题名
            theme_name = f"custom_{datetime.now().strftime('%m%d%H%M%S')}"
            self.all_colors[theme_name] = custom
            self.custom_colors[theme_name] = custom
            self.current_color = theme_name
            self.apply_color()
            self.auto_save()
            dialog.destroy()

        def apply_temp():
            custom = {key: var.get() for key, var in color_vars.items()}
            self.all_colors["_temp"] = custom
            self.custom_colors["_temp"] = custom
            self.current_color = "_temp"
            self.apply_color()
            self.auto_save()

        tk.Button(btn_frame, text="应用", command=apply_temp, font=("Microsoft YaHei", 10), width=8).pack(side=tk.LEFT, padx=5)
        tk.Button(btn_frame, text="保存", command=save_theme, font=("Microsoft YaHei", 10), width=8).pack(side=tk.LEFT, padx=5)

        # 初始化预览
        self._preview_theme(color_vars)

    def _preview_theme(self, color_vars):
        """更新预览区域颜色"""
        try:
            bg = color_vars["bg"].get()
            fg = color_vars["fg"].get()
            today = color_vars["today"].get()
            weekend = color_vars["weekend"].get()
            self.preview_title.config(bg=bg, fg=fg)
            self.preview_text.config(bg=weekend, fg=fg)
            self.preview_title.master.config(bg=bg)
        except Exception:
            pass

    def _apply_preset(self, name, color_vars, preview_labels):
        """应用预设主题到颜色选择器并保存"""
        preset = DEFAULT_COLORS[name]
        for key, var in color_vars.items():
            var.set(preset[key])
        for key, label in preview_labels.items():
            label.config(bg=preset[key])
        self._preview_theme(color_vars)
        self.current_color = name
        self.apply_color()
        self.auto_save()

    def start_drag(self, event):
        self.drag_x = event.x
        self.drag_y = event.y

    def on_drag(self, event):
        x = self.root.winfo_x() + event.x - self.drag_x
        y = self.root.winfo_y() + event.y - self.drag_y
        self.root.geometry(f"+{x}+{y}")

    def auto_save(self):
        self.data["content"] = self.text.get("1.0", tk.END).strip()
        self.data["color"] = self.current_color
        self.data["custom_colors"] = self.custom_colors
        self.data["reminders"] = self.reminders
        self.data["schedules"] = self.schedules
        self.data["show_calendar"] = self.show_calendar
        self.data["weather"] = self.weather_info
        self.data["show_clock"] = self.show_clock
        self.data["clock_style"] = self.clock_style
        if self.clock_window is not None and self.clock_window.winfo_exists():
            self.data["clock_position"] = {
                "x": self.clock_window.winfo_x(),
                "y": self.clock_window.winfo_y(),
            }
        return self.save_data()

    def load_data(self):
        if os.path.exists(DATA_FILE):
            try:
                with open(DATA_FILE, "r", encoding="utf-8") as f:
                    return json.load(f)
            except Exception:
                pass
        return {}

    def save_data(self):
        try:
            with open(DATA_FILE, "w", encoding="utf-8") as f:
                json.dump(self.data, f, ensure_ascii=False, indent=2)
            return True
        except Exception as e:
            print(f"[保存失败] {e}")
            return False

    def show_reminders(self):
        """打开提醒列表对话框"""
        dialog = tk.Toplevel(self.root)
        dialog.title("提醒列表")
        dialog.transient(self.root)
        dialog.grab_set()
        dialog.attributes("-topmost", True)

        x = self.root.winfo_x() + 20
        y = self.root.winfo_y() + 40
        dialog.geometry(f"360x400+{x}+{y}")
        dialog.resizable(False, False)

        theme = self.get_theme()

        tk.Label(dialog, text=f"共 {len(self.reminders)} 条提醒", font=("Microsoft YaHei", 11, "bold")).pack(pady=(10, 5))

        # 滚动区域
        canvas = tk.Canvas(dialog, width=340, height=300)
        scrollbar = tk.Scrollbar(dialog, orient="vertical", command=canvas.yview)
        scroll_frame = tk.Frame(canvas)

        scroll_frame.bind(
            "<Configure>",
            lambda e: canvas.configure(scrollregion=canvas.bbox("all"))
        )
        canvas.create_window((0, 0), window=scroll_frame, anchor="nw", width=340)
        canvas.configure(yscrollcommand=scrollbar.set)

        def format_reminder(r, idx):
            t = r.get("type", "once")
            h = r.get("hour", 0)
            m = r.get("minute", 0)
            time_str = f"{h:02d}:{m:02d}"
            msg = r.get("message", "")

            if t == "once":
                if r.get("is_lunar"):
                    date_str = f"农历 {r['year']}年{r['month']}月{r['day']}日"
                else:
                    date_str = f"{r['year']}年{r['month']}月{r['day']}日"
                return f"[{idx+1}] 单次 · {date_str} {time_str}\n    {msg}"
            elif t == "daily":
                return f"[{idx+1}] 每天 · {time_str}\n    {msg}"
            elif t == "weekly":
                wd = WEEKDAYS[r.get("weekday", 0)]
                return f"[{idx+1}] 每周{wd} · {time_str}\n    {msg}"
            elif t == "monthly":
                d = r.get("day", 1)
                return f"[{idx+1}] 每月{d}号 · {time_str}\n    {msg}"
            elif t == "yearly":
                mo = r.get("month", 1)
                d = r.get("day", 1)
                return f"[{idx+1}] 每年{mo}月{d}日 · {time_str}\n    {msg}"
            elif t == "lunar_yearly":
                lm = r.get("lunar_month", 1)
                ld = r.get("lunar_day", 1)
                return f"[{idx+1}] 每年农历{lm}月{ld}日 · {time_str}\n    {msg}"
            elif t == "lunar_monthly":
                ld = r.get("lunar_day", 1)
                return f"[{idx+1}] 每月农历{ld}日 · {time_str}\n    {msg}"
            return f"[{idx+1}] {time_str}\n    {msg}"

        if not self.reminders:
            tk.Label(scroll_frame, text="暂无提醒", fg="gray", font=("Microsoft YaHei", 10)).pack(pady=20)
        else:
            for i, r in enumerate(self.reminders):
                row = tk.Frame(scroll_frame)
                row.pack(fill=tk.X, padx=10, pady=4)

                text = format_reminder(r, i)
                lbl = tk.Label(row, text=text, font=("Microsoft YaHei", 9), anchor="w", justify=tk.LEFT,
                               wraplength=260)
                lbl.pack(side=tk.LEFT, fill=tk.X, expand=True)

                del_btn = tk.Label(row, text="删除", fg="#D32F2F", font=("Microsoft YaHei", 9), cursor="hand2")
                del_btn.pack(side=tk.RIGHT, padx=(4, 0))

                def do_delete(idx=i):
                    self.reminders.pop(idx)
                    self.auto_save()
                    self.remind_count.config(text=f"提醒({len(self.reminders)})")
                    self.build_calendar()
                    dialog.destroy()
                    self.show_reminders()

                del_btn.bind("<Button-1>", lambda e, f=do_delete: f())

        canvas.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)

    def add_schedule(self, year, month, day):
        """为指定日期添加日程安排"""
        dialog = tk.Toplevel(self.root)
        dialog.title("添加日程")
        dialog.transient(self.root)
        dialog.grab_set()
        dialog.attributes("-topmost", True)

        x = self.root.winfo_x() + 20
        y = self.root.winfo_y() + 60
        dialog.geometry(f"300x200+{x}+{y}")
        dialog.resizable(False, False)

        tk.Label(dialog, text=f"{year}年{month}月{day}日", font=("Microsoft YaHei", 11, "bold")).pack(pady=(10, 5))

        # 时间选择器（下拉列表）
        tk.Label(dialog, text="时间（可选）:", font=("Microsoft YaHei", 10)).pack()
        time_frame = tk.Frame(dialog)
        time_frame.pack(pady=2)
        now = datetime.now()
        hour_var = tk.StringVar(value=f"{now.hour:02d}")
        hour_combo = ttk.Combobox(time_frame, textvariable=hour_var,
                                  values=[f"{h:02d}" for h in range(0, 24)],
                                  width=4, state="readonly", font=("Microsoft YaHei", 10))
        hour_combo.pack(side=tk.LEFT, padx=2)
        tk.Label(time_frame, text=":", font=("Microsoft YaHei", 10)).pack(side=tk.LEFT, padx=2)
        minute_var = tk.StringVar(value=f"{now.minute:02d}")
        minute_combo = ttk.Combobox(time_frame, textvariable=minute_var,
                                    values=[f"{m:02d}" for m in range(0, 60)],
                                    width=4, state="readonly", font=("Microsoft YaHei", 10))
        minute_combo.pack(side=tk.LEFT, padx=2)

        tk.Label(dialog, text="日程内容:", font=("Microsoft YaHei", 10)).pack(pady=(8, 2))
        content_entry = tk.Entry(dialog, font=("Microsoft YaHei", 11), width=28)
        content_entry.pack(pady=2)
        content_entry.focus()

        def save():
            content = content_entry.get().strip()
            if not content:
                messagebox.showwarning("内容为空", "请输入日程内容")
                return

            hour = hour_var.get()
            minute = minute_var.get()
            if hour and minute:
                item = f"{hour}:{minute} {content}"
            else:
                item = content

            date_key = f"{year:04d}-{month:02d}-{day:02d}"
            if date_key not in self.schedules:
                self.schedules[date_key] = []
            self.schedules[date_key].append(item)
            if not self.auto_save():
                messagebox.showwarning("保存失败", "日程已添加，但写入文件失败，重启后可能丢失。")
            self.build_calendar()
            dialog.destroy()

        tk.Button(dialog, text="确定", command=save, font=("Microsoft YaHei", 10), width=10).pack(pady=10)

    def set_reminder(self, event=None, prefill=None):
        dialog = tk.Toplevel(self.root)
        dialog.title("设置提醒")
        dialog.transient(self.root)
        dialog.grab_set()
        dialog.attributes("-topmost", True)

        x = self.root.winfo_x() + 10
        y = self.root.winfo_y() + 40
        dialog.geometry(f"280x300+{x}+{y}")
        dialog.resizable(False, False)

        now = datetime.now()
        prefill_year = prefill[0] if prefill else now.year
        prefill_month = prefill[1] if prefill else now.month
        prefill_day = prefill[2] if prefill else now.day

        # 将预填的公历日期转为农历（用于农历类型的默认值）
        prefill_lunar_month = now.month
        prefill_lunar_day = now.day
        if prefill:
            if ZHDATE_OK:
                try:
                    lunar = ZhDate.from_datetime(datetime(prefill_year, prefill_month, prefill_day))
                    prefill_lunar_month = lunar.lunar_month
                    prefill_lunar_day = lunar.lunar_day
                except Exception:
                    pass
            elif CNLUNAR_OK:
                try:
                    lunar_obj = cnlunar.Lunar(datetime(prefill_year, prefill_month, prefill_day))
                    prefill_lunar_month = int(lunar_obj.lunarMonth)
                    prefill_lunar_day = int(lunar_obj.lunarDay)
                except Exception:
                    pass

        # 类型 + 农历选择
        top_frame = tk.Frame(dialog)
        top_frame.pack(pady=6)

        tk.Label(top_frame, text="类型:", font=("Microsoft YaHei", 10)).pack(side=tk.LEFT)
        type_var = tk.StringVar(value="单次")

        # 农历类型需要 zhdate
        all_types = ["单次", "每天", "每周", "每月", "每年", "每年农历", "每月农历"]
        if not ZHDATE_OK:
            all_types = ["单次", "每天", "每周", "每月", "每年"]

        type_combo = ttk.Combobox(top_frame, textvariable=type_var, values=all_types,
                                   width=10, state="readonly", font=("Microsoft YaHei", 10))
        type_combo.pack(side=tk.LEFT, padx=4)

        # 动态区域容器
        dynamic_frame = tk.Frame(dialog)
        dynamic_frame.pack(pady=4)

        # 单次：年月日（下拉列表）
        date_frame = tk.Frame(dynamic_frame)
        tk.Label(date_frame, text="年", font=("Microsoft YaHei", 10)).pack(side=tk.LEFT)
        year_var = tk.StringVar(value=str(prefill_year))
        year_combo = ttk.Combobox(date_frame, textvariable=year_var,
                                  values=[str(y) for y in range(now.year - 5, now.year + 6)],
                                  width=6, state="readonly", font=("Microsoft YaHei", 10))
        year_combo.pack(side=tk.LEFT, padx=2)
        tk.Label(date_frame, text="月", font=("Microsoft YaHei", 10)).pack(side=tk.LEFT)
        month_var = tk.StringVar(value=str(prefill_month))
        month_combo = ttk.Combobox(date_frame, textvariable=month_var,
                                   values=[str(m) for m in range(1, 13)],
                                   width=4, state="readonly", font=("Microsoft YaHei", 10))
        month_combo.pack(side=tk.LEFT, padx=2)
        tk.Label(date_frame, text="日", font=("Microsoft YaHei", 10)).pack(side=tk.LEFT)
        day_var = tk.StringVar(value=str(prefill_day))
        day_combo = ttk.Combobox(date_frame, textvariable=day_var,
                                 values=[str(d) for d in range(1, 32)],
                                 width=4, state="readonly", font=("Microsoft YaHei", 10))
        day_combo.pack(side=tk.LEFT, padx=2)

        # 单次农历切换
        is_lunar = tk.BooleanVar(value=False)
        lunar_cb = tk.Checkbutton(date_frame, text="农历", variable=is_lunar, font=("Microsoft YaHei", 9))
        lunar_cb.pack(side=tk.LEFT, padx=6)
        if not ZHDATE_OK:
            lunar_cb.config(state="disabled")

        # 每周：周几选择
        weekday_frame = tk.Frame(dynamic_frame)
        tk.Label(weekday_frame, text="每周", font=("Microsoft YaHei", 10)).pack(side=tk.LEFT)
        weekday_var = tk.StringVar(value=WEEKDAYS[now.weekday()])
        weekday_combo = ttk.Combobox(weekday_frame, textvariable=weekday_var, values=WEEKDAYS,
                                      width=6, state="readonly", font=("Microsoft YaHei", 10))
        weekday_combo.pack(side=tk.LEFT, padx=4)

        # 每月：几号选择
        monthday_frame = tk.Frame(dynamic_frame)
        tk.Label(monthday_frame, text="每月", font=("Microsoft YaHei", 10)).pack(side=tk.LEFT)
        monthday_var = tk.StringVar(value=str(now.day))
        monthday_combo = ttk.Combobox(monthday_frame, textvariable=monthday_var,
                                       values=[str(i) for i in range(1, 32)],
                                       width=6, state="readonly", font=("Microsoft YaHei", 10))
        monthday_combo.pack(side=tk.LEFT, padx=4)
        tk.Label(monthday_frame, text="号", font=("Microsoft YaHei", 10)).pack(side=tk.LEFT)

        # 每年（公历）：月 + 日
        yearly_frame = tk.Frame(dynamic_frame)
        tk.Label(yearly_frame, text="每年", font=("Microsoft YaHei", 10)).pack(side=tk.LEFT)
        yearly_month_var = tk.StringVar(value=str(prefill_month))
        yearly_month_combo = ttk.Combobox(yearly_frame, textvariable=yearly_month_var,
                                           values=[str(i) for i in range(1, 13)],
                                           width=4, state="readonly", font=("Microsoft YaHei", 10))
        yearly_month_combo.pack(side=tk.LEFT, padx=2)
        tk.Label(yearly_frame, text="月", font=("Microsoft YaHei", 10)).pack(side=tk.LEFT)
        yearly_day_var = tk.StringVar(value=str(prefill_day))
        yearly_day_combo = ttk.Combobox(yearly_frame, textvariable=yearly_day_var,
                                         values=[str(i) for i in range(1, 32)],
                                         width=4, state="readonly", font=("Microsoft YaHei", 10))
        yearly_day_combo.pack(side=tk.LEFT, padx=2)
        tk.Label(yearly_frame, text="日", font=("Microsoft YaHei", 10)).pack(side=tk.LEFT)

        # 每年农历：农历月 + 农历日
        lunar_year_frame = tk.Frame(dynamic_frame)
        tk.Label(lunar_year_frame, text="农历", font=("Microsoft YaHei", 10)).pack(side=tk.LEFT)
        lunar_month_var = tk.StringVar(value=str(prefill_lunar_month))
        lunar_month_combo = ttk.Combobox(lunar_year_frame, textvariable=lunar_month_var,
                                          values=[str(i) for i in range(1, 13)],
                                          width=4, state="readonly", font=("Microsoft YaHei", 10))
        lunar_month_combo.pack(side=tk.LEFT, padx=2)
        tk.Label(lunar_year_frame, text="月", font=("Microsoft YaHei", 10)).pack(side=tk.LEFT)
        lunar_day_var = tk.StringVar(value=str(prefill_lunar_day))
        lunar_day_combo = ttk.Combobox(lunar_year_frame, textvariable=lunar_day_var,
                                        values=[str(i) for i in range(1, 31)],
                                        width=4, state="readonly", font=("Microsoft YaHei", 10))
        lunar_day_combo.pack(side=tk.LEFT, padx=2)
        tk.Label(lunar_year_frame, text="日", font=("Microsoft YaHei", 10)).pack(side=tk.LEFT)

        # 每月农历：农历日
        lunar_monthly_frame = tk.Frame(dynamic_frame)
        tk.Label(lunar_monthly_frame, text="每月农历", font=("Microsoft YaHei", 10)).pack(side=tk.LEFT)
        lunar_monthly_day_var = tk.StringVar(value=str(prefill_lunar_day))
        lunar_monthly_day_combo = ttk.Combobox(lunar_monthly_frame, textvariable=lunar_monthly_day_var,
                                                values=[str(i) for i in range(1, 31)],
                                                width=4, state="readonly", font=("Microsoft YaHei", 10))
        lunar_monthly_day_combo.pack(side=tk.LEFT, padx=2)
        tk.Label(lunar_monthly_frame, text="日", font=("Microsoft YaHei", 10)).pack(side=tk.LEFT)

        # 默认显示日期输入
        date_frame.pack()

        def on_type_change(*args):
            # 隐藏所有动态控件
            date_frame.pack_forget()
            weekday_frame.pack_forget()
            monthday_frame.pack_forget()
            yearly_frame.pack_forget()
            lunar_year_frame.pack_forget()
            lunar_monthly_frame.pack_forget()
            t = type_var.get()
            if t == "单次":
                date_frame.pack()
            elif t == "每周":
                weekday_frame.pack()
            elif t == "每月":
                monthday_frame.pack()
            elif t == "每年":
                yearly_frame.pack()
            elif t == "每年农历":
                lunar_year_frame.pack()
            elif t == "每月农历":
                lunar_monthly_frame.pack()
            # 每天不需要额外输入

        type_var.trace("w", on_type_change)

        # 时间选择器（下拉列表）
        time_frame = tk.Frame(dialog)
        time_frame.pack(pady=6)
        tk.Label(time_frame, text="时间", font=("Microsoft YaHei", 10)).pack(side=tk.LEFT)
        hour_var = tk.StringVar(value=f"{now.hour:02d}")
        hour_combo = ttk.Combobox(time_frame, textvariable=hour_var,
                                  values=[f"{h:02d}" for h in range(0, 24)],
                                  width=4, state="readonly", font=("Microsoft YaHei", 10))
        hour_combo.pack(side=tk.LEFT, padx=2)
        tk.Label(time_frame, text=":", font=("Microsoft YaHei", 10)).pack(side=tk.LEFT)
        minute_var = tk.StringVar(value=f"{now.minute:02d}")
        minute_combo = ttk.Combobox(time_frame, textvariable=minute_var,
                                    values=[f"{m:02d}" for m in range(0, 60)],
                                    width=4, state="readonly", font=("Microsoft YaHei", 10))
        minute_combo.pack(side=tk.LEFT, padx=2)

        # 提醒内容（多行）
        tk.Label(dialog, text="提醒内容:", font=("Microsoft YaHei", 10)).pack(pady=(6, 2))
        msg_entry = tk.Text(dialog, font=("Microsoft YaHei", 11), width=26, height=3, wrap=tk.WORD)
        msg_entry.pack(pady=2)

        # 提示标签
        hint_label = tk.Label(dialog, text="", fg="gray", font=("Microsoft YaHei", 9))
        hint_label.pack()

        def on_lunar_change(*args):
            if is_lunar.get() and type_var.get() == "单次":
                hint_label.config(text="农历日期将自动转换为公历提醒")
            else:
                hint_label.config(text="")
        is_lunar.trace("w", on_lunar_change)
        type_var.trace("w", on_lunar_change)

        def save():
            try:
                try:
                    hour = int(hour_var.get())
                    minute = int(minute_var.get())
                except ValueError:
                    messagebox.showwarning("格式错误", "时间选择无效")
                    return

                msg = msg_entry.get("1.0", tk.END).strip()
                if not msg:
                    messagebox.showwarning("内容为空", "请输入提醒内容")
                    return

                t = type_var.get()
                lunar = is_lunar.get()
                label = ""

                if t == "单次":
                    try:
                        year = int(year_var.get())
                        month = int(month_var.get())
                        day = int(day_var.get())
                    except ValueError:
                        messagebox.showwarning("格式错误", "日期选择无效")
                        return

                    if lunar:
                        if not ZHDATE_OK:
                            messagebox.showwarning("未安装", "请先安装 zhdate 库")
                            return
                        lunar_date = ZhDate(year, month, day)
                        solar_date = lunar_date.to_datetime()
                        remind_dt = solar_date.replace(hour=hour, minute=minute)
                        hint_label.config(text=f"农历→公历: {remind_dt.strftime('%Y-%m-%d')}")
                    else:
                        remind_dt = datetime(year, month, day, hour, minute)

                    if remind_dt < datetime.now():
                        messagebox.showwarning("时间已过期", "单次提醒时间不能早于当前时间")
                        return

                    self.reminders.append({
                        "type": "once",
                        "year": year, "month": month, "day": day,
                        "hour": hour, "minute": minute,
                        "message": msg,
                        "last_triggered": None,
                        "is_lunar": lunar,
                    })
                    if lunar:
                        label = "[农历] "

                elif t == "每天":
                    self.reminders.append({
                        "type": "daily",
                        "hour": hour, "minute": minute,
                        "message": msg,
                        "last_triggered": None,
                        "is_lunar": False,
                    })
                    label = "[每天] "

                elif t == "每周":
                    wd_name = weekday_var.get()
                    wd_index = WEEKDAYS.index(wd_name)
                    self.reminders.append({
                        "type": "weekly",
                        "weekday": wd_index,
                        "hour": hour, "minute": minute,
                        "message": msg,
                        "last_triggered": None,
                        "is_lunar": False,
                    })
                    label = f"[每周{wd_name}] "

                elif t == "每月":
                    md = int(monthday_var.get())
                    self.reminders.append({
                        "type": "monthly",
                        "day": md,
                        "hour": hour, "minute": minute,
                        "message": msg,
                        "last_triggered": None,
                        "is_lunar": False,
                    })
                    label = f"[每月{md}号] "

                elif t == "每年":
                    ym = int(yearly_month_var.get())
                    yd = int(yearly_day_var.get())
                    self.reminders.append({
                        "type": "yearly",
                        "month": ym,
                        "day": yd,
                        "hour": hour, "minute": minute,
                        "message": msg,
                        "last_triggered": None,
                        "is_lunar": False,
                    })
                    label = f"[每年{ym}月{yd}日] "

                elif t == "每年农历":
                    lm = int(lunar_month_var.get())
                    ld = int(lunar_day_var.get())
                    self.reminders.append({
                        "type": "lunar_yearly",
                        "lunar_month": lm,
                        "lunar_day": ld,
                        "hour": hour, "minute": minute,
                        "message": msg,
                        "last_triggered": None,
                        "is_lunar": True,
                    })
                    label = f"[每年农历{lm}月{ld}日] "

                elif t == "每月农历":
                    ld = int(lunar_monthly_day_var.get())
                    self.reminders.append({
                        "type": "lunar_monthly",
                        "lunar_day": ld,
                        "hour": hour, "minute": minute,
                        "message": msg,
                        "last_triggered": None,
                        "is_lunar": True,
                    })
                    label = f"[每月农历{ld}日] "

                if not self.auto_save():
                    messagebox.showwarning("保存失败", "提醒已添加，但写入文件失败，重启后可能丢失。")
                self.remind_count.config(text=f"提醒({len(self.reminders)})")
                self.build_calendar()
                dialog.destroy()

            except ValueError as e:
                messagebox.showwarning("日期错误", f"日期无效: {e}")
            except Exception as e:
                messagebox.showerror("保存失败", f"发生错误: {e}")

        tk.Button(dialog, text="确定", command=save, font=("Microsoft YaHei", 10), width=10).pack(pady=8)

    def start_reminder_thread(self):
        def check():
            # 先等待一小段时间，避免启动时大量弹窗
            time.sleep(5)
            while True:
                now = datetime.now()
                today_str = now.strftime("%Y-%m-%d")

                for r in self.reminders:
                    if r.get("last_triggered") == today_str:
                        continue

                    hour = r.get("hour", 0)
                    minute = r.get("minute", 0)

                    # 精确匹配当前分钟
                    if now.hour != hour or now.minute != minute:
                        continue

                    should_trigger = False
                    t = r.get("type", "once")

                    if t == "once":
                        dt = datetime(r["year"], r["month"], r["day"], hour, minute)
                        if dt.date() == now.date():
                            should_trigger = True
                            r["done"] = True
                    elif t == "daily":
                        should_trigger = True
                    elif t == "weekly":
                        if now.weekday() == r.get("weekday", 0):
                            should_trigger = True
                    elif t == "monthly":
                        if now.day == r.get("day", 1):
                            should_trigger = True
                    elif t == "yearly":
                        if now.month == r.get("month") and now.day == r.get("day"):
                            should_trigger = True
                    elif t == "lunar_yearly":
                        if ZHDATE_OK:
                            try:
                                today_lunar = ZhDate.from_datetime(now)
                                if (today_lunar.lunar_month == r.get("lunar_month") and
                                        today_lunar.lunar_day == r.get("lunar_day")):
                                    should_trigger = True
                            except Exception:
                                pass
                        elif CNLUNAR_OK:
                            try:
                                today_lunar = cnlunar.Lunar(now)
                                if (int(today_lunar.lunarMonth) == r.get("lunar_month") and
                                        int(today_lunar.lunarDay) == r.get("lunar_day")):
                                    should_trigger = True
                            except Exception:
                                pass
                    elif t == "lunar_monthly":
                        if ZHDATE_OK:
                            try:
                                today_lunar = ZhDate.from_datetime(now)
                                if today_lunar.lunar_day == r.get("lunar_day"):
                                    should_trigger = True
                            except Exception:
                                pass
                        elif CNLUNAR_OK:
                            try:
                                today_lunar = cnlunar.Lunar(now)
                                if int(today_lunar.lunarDay) == r.get("lunar_day"):
                                    should_trigger = True
                            except Exception:
                                pass

                    if should_trigger:
                        r["last_triggered"] = today_str
                        self.save_data()
                        title = "⭐ 农历提醒" if r.get("is_lunar") else "🔔 提醒"
                        msg = r["message"]
                        time_str = f"{hour:02d}:{minute:02d}"
                        self.root.after(0, lambda t=title, m=msg, ts=time_str: self._show_reminder_popup(t, m, ts))

                # 对齐到下一个整分钟
                now = datetime.now()
                sleep_seconds = 60 - now.second + 1
                time.sleep(max(1, sleep_seconds))
        threading.Thread(target=check, daemon=True).start()

    def _show_reminder_popup(self, title, message, time_str):
        """弹出置顶提醒窗口 - 美化版"""
        popup = tk.Toplevel(self.root)
        popup.title("提醒")
        popup.attributes("-topmost", True)
        popup.overrideredirect(True)
        popup.resizable(False, False)

        # 居中显示
        popup.update_idletasks()
        sw = popup.winfo_screenwidth()
        sh = popup.winfo_screenheight()
        w, h = 340, 200
        x = (sw - w) // 2
        y = (sh - h) // 2
        popup.geometry(f"{w}x{h}+{x}+{y}")

        # 主容器带圆角效果（用 Frame 模拟）
        main_bg = "#FFFFFF"
        accent = "#D32F2F" if "班" in title or "农历" in title else "#FF9800"

        container = tk.Frame(popup, bg=main_bg, highlightbackground="#E0E0E0", highlightthickness=1)
        container.pack(fill=tk.BOTH, expand=True, padx=0, pady=0)

        # 顶部彩色条
        bar = tk.Frame(container, bg=accent, height=4)
        bar.pack(fill=tk.X)

        # 图标 + 标题
        header = tk.Frame(container, bg=main_bg)
        header.pack(pady=(16, 4))
        tk.Label(header, text="🔔", bg=main_bg, font=("Microsoft YaHei", 20)).pack(side=tk.LEFT, padx=(0, 8))
        tk.Label(header, text=title.replace("⭐ ", "").replace("🔔 ", ""),
                 bg=main_bg, fg=accent, font=("Microsoft YaHei", 14, "bold")).pack(side=tk.LEFT)

        # 时间
        tk.Label(container, text=f"⏰ {time_str}", bg=main_bg, fg="#888888",
                 font=("Microsoft YaHei", 10)).pack(pady=(4, 2))

        # 分隔线
        sep = tk.Frame(container, bg="#EEEEEE", height=1)
        sep.pack(fill=tk.X, padx=20, pady=6)

        # 消息内容
        tk.Label(container, text=message, bg=main_bg, fg="#333333",
                 font=("Microsoft YaHei", 12), wraplength=280).pack(pady=(2, 10))

        # 按钮
        btn_frame = tk.Frame(container, bg=main_bg)
        btn_frame.pack(pady=(0, 16))
        btn = tk.Label(btn_frame, text="知道了", bg=accent, fg="#FFFFFF",
                       font=("Microsoft YaHei", 11, "bold"),
                       padx=30, pady=6, cursor="hand2")
        btn.pack()
        btn.bind("<Button-1>", lambda e: popup.destroy())
        btn.bind("<Enter>", lambda e: btn.config(bg="#B71C1C" if accent == "#D32F2F" else "#F57C00"))
        btn.bind("<Leave>", lambda e: btn.config(bg=accent))

        # 播放提示音（Windows）
        try:
            import winsound
            winsound.MessageBeep(winsound.MB_ICONEXCLAMATION)
        except Exception:
            pass

    def _is_valid_location(self, location):
        return (
            isinstance(location, dict)
            and location.get("latitude") is not None
            and location.get("longitude") is not None
        )

    def _build_location(self, latitude, longitude, name="当前位置", source="auto"):
        return {
            "latitude": float(latitude),
            "longitude": float(longitude),
            "name": short_location_name(name),
            "source": source,
        }

    def _detect_windows_location(self):
        if sys.platform != "win32":
            return None

        script = r"""
try {
  Add-Type -AssemblyName System.Device
  $watcher = New-Object System.Device.Location.GeoCoordinateWatcher([System.Device.Location.GeoPositionAccuracy]::Default)
  $ok = $watcher.TryStart($false, [TimeSpan]::FromSeconds(5))
  if ($ok -and -not $watcher.Position.Location.IsUnknown) {
    Write-Output ("{0},{1}" -f $watcher.Position.Location.Latitude, $watcher.Position.Location.Longitude)
  }
} catch {}
"""
        creationflags = getattr(subprocess, "CREATE_NO_WINDOW", 0)
        try:
            result = subprocess.run(
                ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", script],
                capture_output=True,
                text=True,
                timeout=8,
                creationflags=creationflags,
            )
            output = result.stdout.strip()
            if not output or "," not in output:
                return None
            lat, lon = output.split(",", 1)
            return self._build_location(lat, lon, "当前位置", "windows")
        except Exception:
            return None

    def _detect_ip_location(self):
        urls = [
            "https://ipapi.co/json/",
            "http://ip-api.com/json/?fields=status,message,country,regionName,city,lat,lon&lang=zh-CN",
        ]
        for url in urls:
            try:
                data = fetch_json(url)
                if "ipapi.co" in url:
                    lat = data.get("latitude")
                    lon = data.get("longitude")
                    city = data.get("city") or data.get("region") or "当前位置"
                else:
                    if data.get("status") != "success":
                        continue
                    lat = data.get("lat")
                    lon = data.get("lon")
                    city = data.get("city") or data.get("regionName") or "当前位置"
                if lat is not None and lon is not None:
                    return self._normalize_location_name(self._build_location(lat, lon, city, "ip"))
            except Exception:
                continue
        return None

    def _detect_location(self):
        return self._detect_windows_location() or self._detect_ip_location()

    def _normalize_location_name(self, location):
        name = location.get("name")
        if not name or not name.isascii():
            return location
        try:
            localized = self._geocode_location(name)
            if localized:
                localized["source"] = location.get("source", "auto")
                return localized
        except Exception:
            pass
        return location

    def _geocode_location(self, query):
        query = (query or "").strip()
        if not query:
            return None

        suffixes = ("特别行政区", "自治州", "地区", "市", "区", "县", "镇", "乡", "省")
        candidates = [query]
        for suffix in suffixes:
            if query.endswith(suffix) and len(query) > len(suffix):
                candidates.append(query[:-len(suffix)])

        seen = set()
        for name in candidates:
            if not name or name in seen:
                continue
            seen.add(name)
            params = urllib.parse.urlencode({
                "name": name,
                "count": 1,
                "language": "zh",
                "format": "json",
            })
            data = fetch_json(f"https://geocoding-api.open-meteo.com/v1/search?{params}")
            results = data.get("results") or []
            if not results:
                continue
            item = results[0]
            return self._build_location(
                item["latitude"],
                item["longitude"],
                item.get("name") or name,
                "manual",
            )
        return None

    def _fetch_weather_summary(self, location):
        params = urllib.parse.urlencode({
            "latitude": location["latitude"],
            "longitude": location["longitude"],
            "current": "temperature_2m,weather_code",
            "daily": "weather_code,temperature_2m_max,temperature_2m_min",
            "timezone": "auto",
            "forecast_days": 7,
        })
        data = fetch_json(f"https://api.open-meteo.com/v1/forecast?{params}")

        current = data.get("current") or {}
        daily = data.get("daily") or {}
        current_code = current.get("weather_code")
        daily_codes = daily.get("weather_code") or []
        code = current_code if current_code is not None else (daily_codes[0] if daily_codes else None)
        temp = current.get("temperature_2m")
        tmin = (daily.get("temperature_2m_min") or [None])[0]
        tmax = (daily.get("temperature_2m_max") or [None])[0]
        forecast = self._build_weekly_forecast(daily)

        text = f"{short_location_name(location.get('name'))} {weather_code_to_text(code)} {format_temp(temp)}°"
        if tmin is not None and tmax is not None:
            text += f" {format_temp(tmin)}-{format_temp(tmax)}°"
        return {
            "display": text,
            "icon": weather_code_to_icon(code),
            "code": code,
            "temperature": temp,
            "forecast": forecast,
        }

    def _fetch_weather_text(self, location):
        return self._fetch_weather_summary(location)["display"]

    def _build_weekly_forecast(self, daily):
        dates = daily.get("time") or []
        codes = daily.get("weather_code") or []
        mins = daily.get("temperature_2m_min") or []
        maxs = daily.get("temperature_2m_max") or []
        forecast = []
        for idx, date_text in enumerate(dates[:7]):
            code = codes[idx] if idx < len(codes) else None
            forecast.append({
                "date": date_text,
                "code": code,
                "icon": weather_code_to_icon(code),
                "weather": weather_code_to_text(code),
                "min": mins[idx] if idx < len(mins) else None,
                "max": maxs[idx] if idx < len(maxs) else None,
            })
        return forecast

    def refresh_weather(self):
        if self.weather_refreshing:
            return
        self.weather_refreshing = True
        self.update_date_info()
        threading.Thread(target=self._weather_worker, daemon=True).start()

    def _weather_worker(self):
        try:
            location = self.weather_location if self._is_valid_location(self.weather_location) else None
            if location is None:
                location = self._detect_location()
            if location is None:
                self.root.after(0, self._handle_weather_location_missing)
                return
            location = self._normalize_location_name(location)
            weather = self._fetch_weather_summary(location)
            self.root.after(0, lambda loc=location, summary=weather: self._apply_weather_result(loc, summary))
        except Exception:
            self.root.after(0, self._handle_weather_error)

    def _apply_weather_result(self, location, weather):
        self.weather_refreshing = False
        self.weather_location = location
        self.weather_text = weather["display"]
        self.weather_icon = weather.get("icon", WEATHER_ICON_DEFAULT)
        self.weather_info = {
            "location": location,
            "display": self.weather_text,
            "icon": self.weather_icon,
            "code": weather.get("code"),
            "temperature": weather.get("temperature"),
            "forecast": weather.get("forecast", []),
            "updated_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        }
        self.data["weather"] = self.weather_info
        self.save_data()
        self.update_date_info()
        self.root.after(WEATHER_UPDATE_INTERVAL_MS, self.refresh_weather)

    def _handle_weather_error(self):
        self.weather_refreshing = False
        if not self.weather_text or self.weather_text == "天气加载中":
            self.weather_text = "天气暂不可用"
            self.weather_icon = WEATHER_ICON_DEFAULT
        self.update_date_info()
        self.root.after(WEATHER_RETRY_INTERVAL_MS, self.refresh_weather)

    def _handle_weather_location_missing(self):
        self.weather_refreshing = False
        self.weather_text = "天气未设置"
        self.weather_icon = WEATHER_ICON_DEFAULT
        self.update_date_info()
        self.prompt_weather_location()

    def prompt_weather_location(self, event=None, force=False):
        if self.weather_prompt_open:
            return
        self.weather_prompt_open = True
        try:
            prompt = "请输入天气城市名：" if force else "无法自动定位，请输入城市名："
            current_city = ""
            if self._is_valid_location(self.weather_location):
                current_city = self.weather_location.get("name", "")
            city = simpledialog.askstring(
                "天气位置",
                prompt,
                parent=self.root,
                initialvalue=current_city,
            )
        finally:
            self.weather_prompt_open = False

        if not city:
            if force or not self._is_valid_location(self.weather_location):
                self.weather_text = "天气未设置"
                self.update_date_info()
            return

        self.weather_text = "天气加载中"
        self.weather_icon = WEATHER_ICON_DEFAULT
        self.update_date_info()
        threading.Thread(target=self._manual_weather_worker, args=(city.strip(),), daemon=True).start()

    def _manual_weather_worker(self, city):
        try:
            location = self._geocode_location(city)
            if location is None:
                self.root.after(0, lambda: self._handle_manual_weather_error("未找到这个位置，请换个城市名试试。"))
                return
            weather = self._fetch_weather_summary(location)
            self.root.after(0, lambda loc=location, summary=weather: self._apply_weather_result(loc, summary))
        except Exception:
            self.root.after(0, lambda: self._handle_manual_weather_error("天气获取失败，请稍后再试。"))

    def _handle_manual_weather_error(self, message):
        self.weather_refreshing = False
        self.weather_text = "天气未设置"
        self.weather_icon = WEATHER_ICON_DEFAULT
        self.update_date_info()
        messagebox.showwarning("天气位置", message)

    def show_weather_forecast(self):
        forecast = self.weather_info.get("forecast") if isinstance(self.weather_info, dict) else None
        if not forecast:
            messagebox.showinfo("天气预报", "天气预报正在加载，请稍后再试。")
            if not self.weather_refreshing:
                self.refresh_weather()
            return

        dialog = tk.Toplevel(self.root)
        dialog.title("未来一周天气")
        dialog.transient(self.root)
        dialog.attributes("-topmost", True)
        dialog.resizable(False, False)

        w, h = 320, 330
        x = self.root.winfo_x() + 20
        y = self.root.winfo_y() + 60
        dialog.geometry(f"{w}x{h}+{x}+{y}")

        theme = self.get_theme()
        dialog.configure(bg=theme["bg"])

        location_name = "当前位置"
        if self._is_valid_location(self.weather_location):
            location_name = self.weather_location.get("name", location_name)
        updated_at = self.weather_info.get("updated_at", "")

        header = tk.Frame(dialog, bg=theme["bg"])
        header.pack(fill=tk.X, padx=14, pady=(12, 6))

        tk.Label(
            header,
            text=f"{location_name} 未来一周",
            bg=theme["bg"],
            fg=theme["fg"],
            font=("Microsoft YaHei", 11, "bold"),
            anchor="w",
        ).pack(side=tk.LEFT, fill=tk.X, expand=True)

        change_btn = tk.Label(
            header,
            text="⚙",
            bg=theme["bg"],
            fg="#1976D2",
            font=("Segoe UI Symbol", 11, "bold"),
            cursor="hand2",
        )
        change_btn.pack(side=tk.RIGHT)
        change_btn.bind("<Button-1>", lambda e: (dialog.destroy(), self.prompt_weather_location(force=True)))

        if updated_at:
            tk.Label(
                dialog,
                text=f"更新：{updated_at[5:16]}",
                bg=theme["bg"],
                fg="#777777",
                font=("Microsoft YaHei", 8),
                anchor="w",
            ).pack(fill=tk.X, padx=14, pady=(0, 6))

        for item in forecast[:7]:
            row = tk.Frame(dialog, bg=theme["bg"])
            row.pack(fill=tk.X, padx=14, pady=3)

            date_label = self._format_forecast_date(item.get("date"))
            icon = item.get("icon") or WEATHER_ICON_DEFAULT
            temp_text = f"{format_temp(item.get('min'))}-{format_temp(item.get('max'))}°"

            tk.Label(row, text=date_label, bg=theme["bg"], fg=theme["fg"],
                     font=("Microsoft YaHei", 9), width=9, anchor="w").pack(side=tk.LEFT)
            tk.Label(row, text=icon, bg=theme["bg"], fg=weather_icon_color(icon, theme),
                     font=("Segoe UI Symbol", 11, "bold"), width=3).pack(side=tk.LEFT)
            tk.Label(row, text=item.get("weather", "未知"), bg=theme["bg"], fg=theme["fg"],
                     font=("Microsoft YaHei", 9), width=10, anchor="w").pack(side=tk.LEFT)
            tk.Label(row, text=temp_text, bg=theme["bg"], fg=theme.get("today", theme["fg"]),
                     font=("Microsoft YaHei", 9, "bold"), anchor="e").pack(side=tk.RIGHT)

        close_btn = tk.Label(
            dialog,
            text="关闭",
            bg=theme.get("weekend", "#EEEEEE"),
            fg=theme["fg"],
            font=("Microsoft YaHei", 9),
            cursor="hand2",
            padx=16,
            pady=3,
        )
        close_btn.pack(pady=(8, 12))
        close_btn.bind("<Button-1>", lambda e: dialog.destroy())

    def _format_forecast_date(self, date_text):
        try:
            dt = datetime.strptime(date_text, "%Y-%m-%d")
        except Exception:
            return date_text or ""
        if dt.date() == datetime.now().date():
            return "今天"
        weekday = WEEKDAYS[dt.weekday()]
        return f"{dt.month}/{dt.day} {weekday}"

    def update_date_info(self):
        now = datetime.now()
        day_of_year = now.timetuple().tm_yday
        week_of_year = now.isocalendar().week
        constellation = get_constellation(now.month, now.day)
        self.date_text_label.config(text=f"今天第{day_of_year}天 第{week_of_year}周 {constellation}")
        self.weather_icon_label.config(
            text=self.weather_icon or WEATHER_ICON_DEFAULT,
            fg=weather_icon_color(self.weather_icon, self.get_theme()),
        )
        self.weather_text_label.config(text=self.weather_text or "天气加载中")

    def update_time(self):
        now = datetime.now()
        self.time_label.config(text=now.strftime("%H:%M"))
        self.update_date_info()

        # 跨天检测：日期变化时自动重建日历
        if now.year != self.cal_year or now.month != self.cal_month:
            self.cal_year = now.year
            self.cal_month = now.month
            self.build_calendar()
        elif now.day != getattr(self, '_last_checked_day', now.day):
            self.build_calendar()
        self._last_checked_day = now.day

        self.root.after(60000, self.update_time)

    def _write_pid(self):
        """写入进程 ID 到文件，用于外部脚本判断是否已启动"""
        try:
            pid_file = os.path.join(_app_dir(), "yuran.pid")
            with open(pid_file, "w", encoding="utf-8") as f:
                f.write(str(os.getpid()))
        except Exception:
            pass

    def _remove_pid(self):
        """关闭时删除 pid 文件"""
        try:
            pid_file = os.path.join(_app_dir(), "yuran.pid")
            if os.path.exists(pid_file):
                os.remove(pid_file)
        except Exception:
            pass

    def on_close(self):
        # 保存窗口位置
        self.data["position"] = {
            "x": self.root.winfo_x(),
            "y": self.root.winfo_y(),
        }
        self.auto_save()
        self._remove_pid()
        self.root.destroy()


def _kill_old_instance():
    """如果已有实例在运行，杀掉旧进程"""
    pid_file = os.path.join(_app_dir(), "yuran.pid")
    if not os.path.exists(pid_file):
        return
    try:
        with open(pid_file, "r", encoding="utf-8") as f:
            old_pid = int(f.read().strip())
        if old_pid == os.getpid():
            return
        # Windows: 尝试终止旧进程
        handle = ctypes.windll.kernel32.OpenProcess(1, False, old_pid)
        if handle:
            ctypes.windll.kernel32.TerminateProcess(handle, 0)
            ctypes.windll.kernel32.CloseHandle(handle)
            time.sleep(0.3)
    except Exception:
        pass


def main():
    _kill_old_instance()
    root = tk.Tk()
    app = StickyNote(root)
    root.mainloop()


if __name__ == "__main__":
    main()
