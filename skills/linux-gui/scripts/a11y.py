#!/usr/bin/env python3
"""AT-SPI のツリーを agent 向けに絞り込んで出し、要素を名前やパスで操作する。

  a11y.py apps                      AT-SPI に載っているアプリ一覧
  a11y.py tree [--pid P] [--depth N] [--all]
  a11y.py find TEXT [--pid P]       name/role に TEXT を含む要素
  a11y.py do PATH [ACTION] [--pid P]   PATH は tree/find が出す 0.3.1 形式
  a11y.py focus PATH [--pid P]      要素にキーボードフォーカスを移す
  a11y.py text PATH TEXT [--pid P]  編集可能な要素に文字列を入れる（IME を通らない）

--pid を省くと niri のフォーカス中ウィンドウのアプリを対象にする。
"""
import argparse
import json
import subprocess
import sys

import pyatspi
from gi.repository import GLib

# 名前が無くても構造として残す role（これ以外の無名ノードは子だけ辿る）
ACTIONABLE = {"push button", "toggle button", "check box", "radio button", "menu item",
              "check menu item", "radio menu item", "combo box", "text", "entry",
              "password text", "spin button", "slider", "link", "page tab", "list item",
              "table cell", "tree item"}


def focused_pid():
    out = subprocess.run(["niri", "msg", "-j", "focused-window"],
                         capture_output=True, text=True, check=True).stdout
    win = json.loads(out)
    if not win:
        sys.exit("フォーカス中のウィンドウが無い")
    return win["pid"]


def find_app(pid):
    desktop = pyatspi.Registry.getDesktop(0)
    for app in desktop:
        if app is not None and app.get_process_id() == pid:
            return app
    sys.exit(f"pid {pid} のアプリが AT-SPI に無い（Electron は --force-renderer-accessibility が要る）")


def is_showing(acc):
    try:
        return acc.getState().contains(pyatspi.STATE_SHOWING)
    except Exception:
        return False


def describe(acc):
    role = acc.getRoleName()
    name = (acc.name or "").replace("\n", " ")[:80]
    extra = []
    try:
        act = acc.queryAction()
        names = [act.getName(i) for i in range(act.nActions)]
        # GTK4 はウィンドウ全体のアクションを frame に何十個も載せるので切り詰める
        if names:
            more = f",+{len(names) - 4}" if len(names) > 4 else ""
            extra.append("actions=" + ",".join(names[:4]) + more)
    except NotImplementedError:
        pass
    try:
        t = acc.queryText()
        val = t.getText(0, min(t.characterCount, 60)).replace("\n", " ")
        if val and val != name:
            extra.append(f"text={val!r}")
    except NotImplementedError:
        pass
    st = acc.getState()
    for s, label in ((pyatspi.STATE_FOCUSED, "focused"), (pyatspi.STATE_CHECKED, "checked"),
                     (pyatspi.STATE_SELECTED, "selected")):
        if st.contains(s):
            extra.append(label)
    if not st.contains(pyatspi.STATE_SENSITIVE):
        extra.append("disabled")
    return role, name, " ".join(extra)


def walk(acc, path, depth, max_depth, show_all):
    if depth > max_depth or (not show_all and depth > 1 and not is_showing(acc)):
        return
    role, name, extra = describe(acc)
    keep = show_all or name or role in ACTIONABLE
    if keep:
        yield path, depth, role, name, extra
    for i, child in enumerate(acc):
        if child is not None:
            yield from walk(child, f"{path}.{i}" if path else str(i),
                            depth + (1 if keep else 0), max_depth, show_all)


def resolve(app, path):
    acc = app
    for i in path.split("."):
        acc = acc.getChildAtIndex(int(i))
        if acc is None:
            sys.exit(f"パス {path} が見つからない（ツリーが変わった可能性。tree を取り直す）")
    return acc


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("cmd", choices=["apps", "tree", "find", "do", "focus", "text"])
    p.add_argument("args", nargs="*")
    p.add_argument("--pid", type=int)
    p.add_argument("--depth", type=int, default=30)
    p.add_argument("--all", action="store_true", help="非表示・無名ノードも出す")
    a = p.parse_args()

    if a.cmd == "apps":
        for app in pyatspi.Registry.getDesktop(0):
            if app is not None:
                print(app.get_process_id(), app.name, app.childCount)
        return

    app = find_app(a.pid or focused_pid())
    if a.cmd == "tree":
        for path, depth, role, name, extra in walk(app, "", 0, a.depth, a.all):
            print(f"{'  ' * depth}[{path or '-'}] {role} {name!r} {extra}".rstrip())
    elif a.cmd == "find":
        q = a.args[0].lower()
        for path, _, role, name, extra in walk(app, "", 0, a.depth, a.all):
            if q in name.lower() or q in role:
                print(f"[{path}] {role} {name!r} {extra}".rstrip())
    elif a.cmd == "do":
        acc = resolve(app, a.args[0])
        act = acc.queryAction()
        names = [act.getName(i) for i in range(act.nActions)]
        want = a.args[1] if len(a.args) > 1 else names[0]
        if want not in names:
            sys.exit(f"action {want} が無い: {names}")
        act.doAction(names.index(want))
    elif a.cmd == "focus":
        try:
            ok = resolve(app, a.args[0]).queryComponent().grabFocus()
        except GLib.GError:
            ok = False
        if not ok:
            sys.exit("grabFocus 非対応（GTK4 は常に拒否）。do でクリックするか Tab で移る")
    elif a.cmd == "text":
        acc = resolve(app, a.args[0])
        try:
            acc.queryEditableText().setTextContents(a.args[1])
        except NotImplementedError:
            sys.exit("EditableText 非対応（GTK4 の entry など）。focus してから wl-copy + ctrl+v で貼る")


if __name__ == "__main__":
    main()
