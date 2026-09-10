#!/usr/bin/env python3
"""🌟 arunlinux Welcome Center — first-run hub for Arun's laptop."""
import subprocess
import tkinter as tk
from tkinter import ttk, messagebox
import os

BG = "#0f172a"
FG = "#e2e8f0"
ACCENT = "#f97316"
CARD = "#1e293b"


def run(cmd):
    try:
        subprocess.Popen(cmd, shell=True)
    except Exception as e:
        messagebox.showerror("arunlinux", str(e))


def run_term(cmd):
    term = "qterminal" if os.system("command -v qterminal >/dev/null") == 0 else "xfce4-terminal"
    run(f"{term} -e 'bash -c \"{cmd}; echo; read -p \\'Done — press Enter to close...\\'\"' &")


root = tk.Tk()
root.title("Welcome to arunlinux 🌟")
root.geometry("620x560")
root.configure(bg=BG)
root.resizable(False, False)

style = ttk.Style()
style.theme_use("clam")
style.configure("TButton", font=("DejaVu Sans", 11), padding=8)
style.configure("Title.TLabel", background=BG, foreground=ACCENT, font=("DejaVu Sans", 22, "bold"))
style.configure("Sub.TLabel", background=BG, foreground=FG, font=("DejaVu Sans", 11))
style.configure("Card.TFrame", background=CARD)

ttk.Label(root, text="🐧 Welcome to arunlinux!", style="Title.TLabel").pack(pady=(18, 4))
ttk.Label(root, text="Built for your 4 GB laptop — VS Code, Chrome & coding, ready to fly.",
           style="Sub.TLabel").pack(pady=(0, 12))

card = ttk.Frame(root, style="Card.TFrame", padding=16)
card.pack(fill="both", expand=True, padx=18, pady=6)

buttons = [
    ("🔄  Update everything", "sudo apt update && sudo apt full-upgrade -y && flatpak update -y"),
    ("🧑‍💻  Install dev stack (Rust/C++/Go/Node/Java/Kotlin)",
     "sudo /usr/share/arunlinux/../arunlinux/scripts/dev-setup.sh 2>/dev/null || sudo bash ~/linux-for-my-laptop/scripts/dev-setup.sh"),
    ("🖼️  Wallpaper Gallery", None),
    ("⚡  System Optimizer (RAM + battery)", None),
    ("🔧  Driver Installer", None),
    ("📦  Demo: arun-pkg package manager", "arun-pkg --help"),
]

for label, cmd in buttons:
    if "Wallpaper" in label:
        ttk.Button(card, text=label, command=lambda: run("arun-wallpapers &")).pack(fill="x", pady=4)
    elif "Optimizer" in label:
        ttk.Button(card, text=label, command=lambda: run_term("arun-optimizer")).pack(fill="x", pady=4)
    elif "Driver" in label:
        ttk.Button(card, text=label, command=lambda: run_term("sudo arun-drivers")).pack(fill="x", pady=4)
    else:
        ttk.Button(card, text=label, command=lambda c=cmd: run_term(c)).pack(fill="x", pady=4)

dont_show = tk.BooleanVar(value=False)


def close():
    if dont_show.get():
        for p in [os.path.expanduser("~/.config/autostart/arun-welcome.desktop"),
                  "/etc/skel/.config/autostart/arun-welcome.desktop"]:
            try:
                os.path.exists(p) and os.remove(p)
            except OSError:
                pass
    root.destroy()


ttk.Checkbutton(root, text="Don't show again", variable=dont_show).pack(pady=(6, 0))
ttk.Button(root, text="Let's go! 🚀", command=close).pack(pady=10)

root.mainloop()
