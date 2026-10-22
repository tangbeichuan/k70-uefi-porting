import pathlib, re

wsl = pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/wsl')
src = wsl / 'build_keys111.sh'
dst = wsl / 'build_keys122.sh'

s = src.read_text(encoding='utf-8')

old_tokens = '    "usb", "xhci", "pildxe", "pilproxy", "spss", "tzdxe", "charger", "chg",\n'
new_tokens = ('    # keys122: keep the USB *device* stack (UsbInit/UsbDevice/UsbfnDwc3/UsbMsd/'
              'UsbPwrCtrl) so the gadget can expose a RAM disk to the PC.\n'
              '    # Only the host-side drivers stay dropped.\n'
              '    "usbbus", "usbkb", "usbmassstorage", "usbconfig", "usbmouse", "usbnetwork",\n'
              '    "xhci", "pildxe", "pilproxy", "spss", "tzdxe", "charger", "chg",\n')
assert old_tokens in s, 'drop token line not found'
s = s.replace(old_tokens, new_tokens, 1)

anchor = 'python3 /mnt/d/本地项目-01/_tools/patch_menu101.py  # re-apply after gates.py\n'
assert anchor in s, 'menu patch anchor not found'
s = s.replace(anchor, anchor + 'python3 /mnt/d/本地项目-01/_tools/patch_logdisk122.py\n', 1)

s = s.replace('keys111', 'keys122')
dst.write_text(s, encoding='utf-8')
print('wrote', dst)
