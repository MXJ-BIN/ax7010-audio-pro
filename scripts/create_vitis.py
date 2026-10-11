import os
import shutil
import vitis

origin = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
src_xsa = os.path.join(origin, "build", "audio_fourmic.xsa")
# Vitis 2026 rejects project paths that contain spaces.
root = r"D:\ax7010-audio-pro-vitis"
from datetime import datetime
ws = os.path.join(root, "workspaces", datetime.now().strftime("%Y%m%d_%H%M%S"))
xsa = os.path.join(root, "audio_ps_wrapper.xsa")
src_main = os.path.join(origin, "sw", "doa_uart", "main.c")
src_dir = os.path.join(root, "src")

if not os.path.isfile(src_xsa):
    raise SystemExit("Missing " + src_xsa)
src_bit = os.path.join(origin, "build", "project", "ax7010_pro.runs", "impl_1", "audio_ps_wrapper.bit")
if not os.path.isfile(src_bit):
    raise SystemExit("Missing current bitstream; build_bitstream.bat must succeed before Vitis build")
ready_file = os.path.join(origin, "build", "hardware_ready.txt")
if not os.path.isfile(ready_file):
    raise SystemExit("Hardware release gate missing; timing-checked build must finish first")
with open(ready_file) as ready:
    if int(ready.read().strip()) != int(os.path.getmtime(src_bit)):
        raise SystemExit("Hardware release gate does not match current bitstream")
import zipfile
with zipfile.ZipFile(src_xsa) as archive:
    bits = [n for n in archive.namelist() if n.endswith(".bit")]
    with open(src_bit, "rb") as current_bit:
        if len(bits) != 1 or archive.read(bits[0]) != current_bit.read():
            raise SystemExit("XSA and current bitstream differ; rerun successful hardware build")
os.makedirs(src_dir, exist_ok=True)
shutil.copyfile(src_xsa, xsa)
shutil.copyfile(src_main, os.path.join(src_dir, "main.c"))

if os.path.isdir(ws):
    raise SystemExit("Workspace already exists")

client = vitis.create_client()
client.set_workspace(ws)

platform = client.create_platform_component(
    name="audio_plat",
    hw_design=xsa,
    os="standalone",
    cpu="ps7_cortexa9_0",
    domain_name="standalone_ps7",
)
platform.list_domains()
platform.build()

platform_xpfm = client.find_platform_in_repos("audio_plat")
app = client.create_app_component(
    name="doa_uart",
    platform=platform_xpfm,
    domain="standalone_ps7",
    template="hello_world",
)

hello = os.path.join(ws, "doa_uart", "src", "helloworld.c")
if not os.path.isfile(hello):
    raise SystemExit("Missing " + hello)
shutil.copyfile(os.path.join(src_dir, "main.c"), hello)

config = os.path.join(ws, "doa_uart", "src", "UserConfig.cmake")
with open(config, "a", encoding="utf-8") as f:
    f.write("\nlist(APPEND USER_LINK_LIBRARIES m)\n")
# Reserve 0x08000000..0x1fffffff for audio; metadata at 0x07fff000.
# Keep application, heap and stacks entirely below 0x07000000.
linker = os.path.join(ws, "doa_uart", "src", "lscript.ld")
with open(linker, encoding="utf-8") as f: ld = f.read()
old_region = "ORIGIN = 0x100000, LENGTH = 0x1ff00000"
if old_region not in ld: raise SystemExit("Unexpected DDR linker region; refusing unsafe recording reservation")
with open(linker, "w", encoding="utf-8") as f: f.write(ld.replace(old_region, "ORIGIN = 0x100000, LENGTH = 0x06f00000"))
app.build()
elf = os.path.join(ws, "doa_uart", "build", "doa_uart.elf")
if not os.path.isfile(elf):
    raise SystemExit("doa_uart build failed, missing " + elf)
with open(os.path.join(root, "last_workspace.txt"), "w", encoding="utf-8") as f: f.write(ws.replace("\\", "/"))
print("DOA_UART_APP_PASS")
print("ELF " + elf)
vitis.dispose()
