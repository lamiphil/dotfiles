#!/usr/bin/env python3

import json
import subprocess

import gi

gi.require_version("Gdk", "3.0")
gi.require_version("Gtk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gdk, GLib, Gtk, GtkLayerShell

POLL_MS = 75
ZONE_HALF_WIDTH = 90
POPUP_WIDTH = 252
POPUP_HEIGHT = 210
POPUP_Y_GAP = -30

def run_json(cmd):
    out = subprocess.check_output(cmd, text=True)
    return json.loads(out)


def run_text(cmd):
    return subprocess.check_output(cmd, text=True).strip()


class CalendarPopup:
    def __init__(self):
        self.visible = False
        self.popup_x = 0
        self.popup_y = 0
        self.window = Gtk.Window(type=Gtk.WindowType.TOPLEVEL)
        self.window.set_type_hint(Gdk.WindowTypeHint.UTILITY)
        self.window.set_resizable(False)
        self.window.set_accept_focus(False)
        self.window.set_skip_taskbar_hint(True)
        self.window.set_skip_pager_hint(True)
        self.window.set_decorated(False)
        self.window.set_app_paintable(True)
        self.window.set_size_request(POPUP_WIDTH, POPUP_HEIGHT)
        self.window.connect("delete-event", self.on_delete)

        GtkLayerShell.init_for_window(self.window)
        GtkLayerShell.set_layer(self.window, GtkLayerShell.Layer.TOP)
        GtkLayerShell.set_keyboard_mode(self.window, GtkLayerShell.KeyboardMode.NONE)
        GtkLayerShell.set_namespace(self.window, "clock-calendar-popup")
        GtkLayerShell.set_anchor(self.window, GtkLayerShell.Edge.TOP, True)
        GtkLayerShell.set_anchor(self.window, GtkLayerShell.Edge.LEFT, True)
        GtkLayerShell.set_anchor(self.window, GtkLayerShell.Edge.RIGHT, False)
        GtkLayerShell.set_anchor(self.window, GtkLayerShell.Edge.BOTTOM, False)

        provider = Gtk.CssProvider()
        provider.load_from_data(
            b"""
            window.clock-calendar-popup {
              background: transparent;
            }
            .popup-card {
              background: rgba(24, 24, 28, 0.96);
              border: 1px solid rgba(255, 255, 255, 0.08);
              border-radius: 14px;
            }
            .calendar-wrap {
              padding: 12px 14px 14px 14px;
              background: transparent;
            }
            calendar {
              background: transparent;
              color: #f4f1ed;
              border: none;
              padding: 0;
            }
            calendar.header {
              color: #f4f1ed;
            }
            calendar.button {
              color: #f4f1ed;
            }
            calendar:selected {
              background: #ffffff;
              color: #000000;
              border-radius: 999px;
            }
            calendar.highlight {
              color: #f4f1ed;
            }
            """
        )
        screen = Gdk.Screen.get_default()
        Gtk.StyleContext.add_provider_for_screen(
            screen, provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )
        self.window.get_style_context().add_class("clock-calendar-popup")

        card = Gtk.EventBox()
        card.get_style_context().add_class("popup-card")

        outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        outer.get_style_context().add_class("calendar-wrap")

        self.calendar = Gtk.Calendar()
        self.calendar.set_property("show-week-numbers", False)
        self.calendar.set_property("show-heading", True)
        self.calendar.set_property("show-day-names", True)
        outer.pack_start(self.calendar, True, True, 0)

        card.add(outer)
        self.window.add(card)
        self.window.show_all()
        self.window.hide()

        GLib.timeout_add(POLL_MS, self.tick)

    def on_delete(self, *_args):
        Gtk.main_quit()
        return False

    def focused_monitor(self):
        mons = run_json(["hyprctl", "monitors", "-j"])
        for mon in mons:
            if mon.get("focused"):
                return mon
        return mons[0] if mons else None

    def cursor_pos(self):
        raw = run_text(["hyprctl", "cursorpos"])
        x_str, y_str = [part.strip() for part in raw.split(",", 1)]
        return int(float(x_str)), int(float(y_str))

    def hover_zone_contains(self, x, y, mon):
        center_x = mon["x"] + mon["width"] // 2
        bar_h = max(mon.get("reserved", [0, 34, 0, 0])[1], 34)
        return (
            center_x - ZONE_HALF_WIDTH <= x <= center_x + ZONE_HALF_WIDTH
            and mon["y"] <= y <= mon["y"] + bar_h + 2
        )

    def popup_contains(self, x, y):
        return (
            self.popup_x <= x <= self.popup_x + POPUP_WIDTH
            and self.popup_y <= y <= self.popup_y + POPUP_HEIGHT
        )

    def place_popup(self, mon):
        bar_h = max(mon.get("reserved", [0, 34, 0, 0])[1], 34)
        self.popup_x = mon["x"] + (mon["width"] - POPUP_WIDTH) // 2
        self.popup_y = mon["y"] + bar_h + POPUP_Y_GAP
        GtkLayerShell.set_margin(self.window, GtkLayerShell.Edge.LEFT, self.popup_x)
        GtkLayerShell.set_margin(self.window, GtkLayerShell.Edge.TOP, self.popup_y)

    def show(self, mon):
        self.place_popup(mon)
        if not self.visible:
            self.window.show_all()
            self.visible = True

    def hide(self):
        if self.visible:
            self.window.hide()
            self.visible = False

    def tick(self):
        try:
            mon = self.focused_monitor()
            if not mon:
                self.hide()
                return True
            x, y = self.cursor_pos()
            if self.hover_zone_contains(x, y, mon) or self.popup_contains(x, y):
                self.show(mon)
            else:
                self.hide()
        except Exception:
            self.hide()
        return True


if __name__ == "__main__":
    CalendarPopup()
    Gtk.main()
