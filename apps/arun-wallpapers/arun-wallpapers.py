#!/usr/bin/env python3
"""🖼️ arunlinux Wallpaper Gallery — Minecraft / Spiderman / Ultra + more.

Wallpapers live in /usr/share/backgrounds/arunlinux/<category>/*.jpg
(or next to this repo at assets/wallpapers/ when running from source).
All bundled images are original AI art inspired by your themes.
"""
import glob
import os
import subprocess
import tkinter as tk
from tkinter import ttk, messagebox

BG = "#0f172a"
FG = "#e2e8f0"
ACCENT = "#38bdf8"

CANDIDATE_DIRS = [
    "/usr/share/backgrounds/arunlinux",
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "assets", "wallpapers"),
    os.path.expanduser("~/linux-for-my-laptop/assets/wallpapers"),
]

CATEGORIES = [
    ("minecraft", "🧱 Minecraft"),
    ("spiderman", "🕷️ Spiderman"),
    ("ultra", "✨ Ultra Graphics"),
]

try:
    from PIL import Image, ImageTk
    HAS_PIL = True
except ImportError:
    HAS_PIL = False


def find_wallpaper_root():
    for d in CANDIDATE_DIRS:
        d = os.path.normpath(d)
        if os.path.isdir(d):
            return d
    return None


def set_wallpaper(path):
    """Set wallpaper on XFCE + LXQt + fallbacks."""
    ok = False
    # XFCE: set on every monitor property
    try:
        out = subprocess.run(["xfconf-query", "-c", "xfce4-desktop", "-l"],
                             capture_output=True, text=True, timeout=5)
        for line in out.stdout.splitlines():
            if line.strip().endswith("last-image"):
                subprocess.run(["xfconf-query", "-c", "xfce4-desktop", "-p",
                                line.strip(), "-s", path], timeout=5)
                ok = True
    except (FileNotFoundError, subprocess.SubprocessError):
        pass
    # LXQt: pcmanfm-qt sets the desktop background
    try:
        subprocess.run(["pcmanfm-qt", "--set-wallpaper", path], timeout=10)
        ok = True
    except (FileNotFoundError, subprocess.SubprocessError):
        pass
    # Generic fallbacks
    for cmd in (["feh", "--bg-fill", path], ["nitrogen", "--set-zoom-fill", path]):
        try:
            subprocess.run(cmd, timeout=10)
            ok = True
            break
        except (FileNotFoundError, subprocess.SubprocessError):
            continue
    return ok


class Gallery(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("arunlinux Wallpaper Gallery 🖼️")
        self.geometry("760x600")
        self.configure(bg=BG)
        self.root_dir = find_wallpaper_root()
        self.thumbs = []

        style = ttk.Style()
        style.theme_use("clam")
        style.configure("Title.TLabel", background=BG, foreground=ACCENT,
                        font=("DejaVu Sans", 18, "bold"))
        style.configure("Cat.TLabel", background=BG, foreground=FG,
                        font=("DejaVu Sans", 13, "bold"))

        ttk.Label(self, text="🖼️ arunlinux Wallpapers", style="Title.TLabel").pack(pady=10)
        if not HAS_PIL:
            ttk.Label(self, text="Tip: sudo apt install python3-pil — for image previews",
                      style="Cat.TLabel").pack()

        self.notebook = ttk.Notebook(self)
        self.notebook.pack(fill="both", expand=True, padx=12, pady=8)

        if not self.root_dir:
            messagebox.showerror("arunlinux", "No wallpapers found! Run the installer first.")
            self.destroy()
            return

        for folder, title in CATEGORIES:
            self._build_tab(folder, title)
        self._build_tab(None, "🎲 All")

        ttk.Button(self, text="📁 Open wallpaper folder",
                   command=self._open_folder).pack(pady=8)

    def _images(self, folder=None):
        if folder:
            pats = [os.path.join(self.root_dir, folder, "*.jpg"),
                    os.path.join(self.root_dir, folder, "*.png")]
        else:
            pats = [os.path.join(self.root_dir, "*", "*.jpg"),
                    os.path.join(self.root_dir, "*", "*.png")]
        files = []
        for p in pats:
            files.extend(glob.glob(p))
        return sorted(files)

    def _build_tab(self, folder, title):
        frame = ttk.Frame(self.notebook)
        self.notebook.add(frame, text=title)
        canvas = tk.Canvas(frame, bg=BG, highlightthickness=0)
        scroll = ttk.Scrollbar(frame, orient="vertical", command=canvas.yview)
        inner = ttk.Frame(canvas)
        inner.bind("<Configure>", lambda e: canvas.configure(scrollregion=canvas.bbox("all")))
        canvas.create_window((0, 0), window=inner, anchor="nw")
        canvas.configure(yscrollcommand=scroll.set)
        canvas.pack(side="left", fill="both", expand=True)
        scroll.pack(side="right", fill="y")

        files = self._images(folder)
        if not files:
            ttk.Label(inner, text="No images here yet — drop .jpg files into:\n" +
                      os.path.join(self.root_dir, folder or "")).pack(padx=20, pady=20)
            return

        row = col = 0
        for path in files:
            cell = ttk.Frame(inner, padding=6)
            cell.grid(row=row, column=col, padx=6, pady=6)
            name = os.path.splitext(os.path.basename(path))[0].replace("-", " ").replace("_", " ").title()
            if HAS_PIL:
                try:
                    img = Image.open(path)
                    img.thumbnail((220, 124))
                    photo = ImageTk.PhotoImage(img)
                    self.thumbs.append(photo)  # keep reference!
                    btn = tk.Button(cell, image=photo, bg=BG, relief="flat",
                                    command=lambda p=path: self._apply(p))
                    btn.pack()
                except Exception:
                    ttk.Button(cell, text=name, width=24,
                               command=lambda p=path: self._apply(p)).pack()
            else:
                ttk.Button(cell, text=name, width=24,
                           command=lambda p=path: self._apply(p)).pack()
            ttk.Label(cell, text=name, wraplength=220, justify="center").pack()
            col += 1
            if col >= 3:
                col = 0
                row += 1

    def _apply(self, path):
        if set_wallpaper(path):
            messagebox.showinfo("arunlinux", f"Wallpaper applied! 🎉\n{os.path.basename(path)}")
        else:
            messagebox.showwarning("arunlinux",
                                   "Couldn't set wallpaper automatically.\n"
                                   f"File is at:\n{path}")

    def _open_folder(self):
        for fm in ("thunar", "pcmanfm-qt", "xdg-open"):
            try:
                subprocess.Popen([fm, self.root_dir])
                return
            except FileNotFoundError:
                continue


if __name__ == "__main__":
    Gallery().mainloop()
