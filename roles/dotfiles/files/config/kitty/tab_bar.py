# Custom kitty tab bar.
#
#   ( 1  mac-mini-m4/api-server )   2  web-app    3  ~               11:01
#
# The active tab is a rounded pill in the matugen accent colour; other tabs
# are dim text. Tabs are labelled by project (git root / folder name), not by
# program. For ssh tabs the remote path is taken from the shell's title
# ("user@host:~/path") and remembered while a program like nvim runs.
import os
import re
import socket
from urllib.parse import urlparse
from datetime import datetime

from kitty.fast_data_types import Screen, add_timer, get_boss, wcswidth
from kitty.rgb import to_color
from kitty.tab_bar import DrawData, ExtraData, TabBarData, as_rgb


def _rgb(hex_color: str) -> int:
    return as_rgb(int(to_color(hex_color)))


LEFT_CAP = ''
RIGHT_CAP = ''

INACTIVE_FG = _rgb('#6c7086')
INACTIVE_INDEX_FG = _rgb('#45475a')
STATUS_FG = _rgb('#6c7086')
BELL_FG = _rgb('#f38ba8')
ACTIVITY_FG = _rgb('#f9e2af')

SHELLS = {'zsh', 'bash', 'fish', 'sh'}
REMOTE = {'ssh', 'mosh', 'kitten'}
CLOCK_ICON = ''
BELL_ICON = ''
ZOOM_ICON = ''

# "user@host:~/some/path", "host:/path", "~/path" or "/path"
TITLE_PATH = re.compile(r'^(?:[^@\s]+@)?(?:(?P<host>[\w.-]+):\s*)?(?P<path>~[^\s]*|/[^\s]*)$')

_timer_id = None
_root_cache: dict[str, str] = {}


def _redraw(timer_id: int | None) -> None:
    tm = get_boss().active_tab_manager
    if tm is not None:
        tm.mark_tab_bar_dirty()


def _basename(path: str) -> str:
    path = path.rstrip('/')
    if path in ('', '~'):
        return path or '/'
    return os.path.basename(path)


def _local_project(cwd: str) -> str:
    if cwd in _root_cache:
        return _root_cache[cwd]
    home = os.path.expanduser('~')
    name = '~' if cwd == home else _basename(cwd)
    d = cwd
    while d and d not in ('/', home):
        if os.path.exists(os.path.join(d, '.git')):
            name = os.path.basename(d)
            break
        d = os.path.dirname(d)
    _root_cache[cwd] = name
    return name


SSH_OPTS_WITH_ARG = set('BbcDEeFIiJLlmOoPpQRSWw')
LOCAL_HOST = socket.gethostname()


def _short_host(host: str) -> str:
    return host.split('@')[-1].removesuffix('.local')


def _ssh_host(cmdline: list[str]) -> str:
    """Destination host from an ssh/mosh command line."""
    args = iter(cmdline[1:])
    for a in args:
        if a == '--':
            continue
        if a.startswith('-') and len(a) > 1:
            if a[-1] in SSH_OPTS_WITH_ARG and len(a) == 2:
                next(args, None)
            continue
        return _short_host(a.removeprefix('ssh://'))
    return ''


def _remote_location(t, w, title: str) -> tuple[str, str]:
    """(host, path) for an ssh tab: from the title ("user@host:path"), the
    title stack, or an OSC 7 cwd report sent by the remote shell."""
    for c in [title, *reversed(w.title_stack)]:
        m = TITLE_PATH.match(c.strip())
        if m:  # stored on the Tab so it survives config reloads
            t.tab_bar_remote_path = (_short_host(m.group('host') or ''), m.group('path'))
            break
    else:
        url = w.screen.last_reported_cwd
        if url:
            u = urlparse(url.decode() if isinstance(url, bytes) else url)
            if u.path and u.hostname and u.hostname != LOCAL_HOST:
                t.tab_bar_remote_path = (_short_host(u.hostname), u.path)
    return getattr(t, 'tab_bar_remote_path', ('', ''))


def _info(tab: TabBarData) -> tuple[str, str]:
    """Return (label, host) for a tab."""
    title = tab.title.strip()
    t = get_boss().tab_for_id(tab.tab_id)
    if t is None:
        return title, ''

    local_prog, cmd, cwd = '', [''], None
    w = t.active_window
    if w is not None:
        procs = w.child.foreground_processes
        if procs:
            cmd = procs[-1]['cmdline'] or ['']
            local_prog = os.path.basename(cmd[0]).lstrip('-')
        cwd = w.child.foreground_cwd or w.child.current_cwd

    host = ''
    if local_prog in REMOTE and w is not None:
        host, path = _remote_location(t, w, title)
        host = host or _ssh_host(cmd)
        project = _basename(path) if path else title
        label = f'{host}/{project}' if host else project
    elif cwd:
        project = _local_project(cwd)
        plain = local_prog in SHELLS or local_prog in ('nvim', 'vim', 'vi') or not local_prog
        label = project if plain else f'{local_prog} · {project}'
    else:
        label = title

    if t.name:  # a name set by hand always wins
        label = t.name
    return label, host


def _truncate(text: str, width: int) -> str:
    if width <= 0:
        return ''
    if wcswidth(text) <= width:
        return text
    out = ''
    for ch in text:
        if wcswidth(out + ch) > width - 1:
            break
        out += ch
    return out + '…'


def _draw_status(draw_data: DrawData, screen: Screen) -> None:
    parts = []
    parts.append(f'{CLOCK_ICON} {datetime.now().strftime("%H:%M")}')
    text = '   '.join(parts) + ' '
    x = screen.columns - wcswidth(text)
    if x <= screen.cursor.x:
        return
    screen.cursor.bg = as_rgb(int(draw_data.default_bg))
    screen.draw(' ' * (x - screen.cursor.x))
    screen.cursor.fg = STATUS_FG
    screen.cursor.bold = False
    screen.draw(text)


def draw_tab(
    draw_data: DrawData, screen: Screen, tab: TabBarData,
    before: int, max_tab_length: int, index: int, is_last: bool,
    extra_data: ExtraData,
) -> int:
    global _timer_id
    if _timer_id is None:
        _timer_id = add_timer(_redraw, 30.0, True)

    try:
        label, host = _info(tab)
    except Exception:
        label, host = tab.title, ''

    marks = ''
    if tab.needs_attention:
        marks += f' {BELL_ICON}'
    elif tab.has_activity_since_last_focus and not tab.is_active:
        marks += ' ●'
    if tab.layout_name == 'stack' and tab.num_windows > 1:
        marks += f' {ZOOM_ICON}'

    default_bg = as_rgb(int(draw_data.default_bg))
    head = f' {index}  '
    fixed = 2 + wcswidth(head) + wcswidth(marks) + 1 + 1
    label = _truncate(label, min(max_tab_length - fixed, draw_data.max_tab_title_length or 999))

    if screen.cursor.x == 0:
        screen.cursor.bg = default_bg
        screen.draw(' ')

    if tab.is_active:
        bg = as_rgb(draw_data.tab_bg(tab))
        fg = as_rgb(draw_data.tab_fg(tab))
        screen.cursor.bg, screen.cursor.fg = default_bg, bg
        screen.draw(LEFT_CAP)
        screen.cursor.bg, screen.cursor.fg = bg, fg
        screen.cursor.bold = True
        screen.draw(f'{head}{label}{marks} ')
        screen.cursor.bold = False
        screen.cursor.bg, screen.cursor.fg = default_bg, bg
        screen.draw(RIGHT_CAP)
    else:
        screen.cursor.bg = default_bg
        screen.cursor.bold = False
        screen.cursor.fg = INACTIVE_INDEX_FG
        screen.draw(f' {head}')
        screen.cursor.fg = INACTIVE_FG
        screen.draw(label)
        if marks:
            screen.cursor.fg = BELL_FG if tab.needs_attention else ACTIVITY_FG
            screen.draw(marks)
        screen.draw('  ')

    end = screen.cursor.x
    screen.cursor.bg = default_bg
    screen.draw(' ')
    if is_last:
        _draw_status(draw_data, screen)
    return end
