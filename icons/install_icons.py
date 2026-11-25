#!/usr/bin/env python3
"""把 App logo 安装成 Android 启动图标。

Flutter 默认用自带的绿色 Flutter 图标，而且安卓 8+ (API 26+) 会优先读
mipmap-anydpi-v26/ic_launcher.xml 的 adaptive 配置，只替换 PNG 不生效。
本脚本做两件事：
  1) 用仓库里的图标 PNG 覆盖 mipmap-*/ic_launcher.png 与 ic_launcher_round.png
  2) 删除 mipmap-anydpi-v26 里的 ic_launcher*.xml，让所有安卓版本统一用我们的 PNG

用法:
  python3 install_icons.py <android/app/src/main/res 路径> <icons 源目录>
"""
import os
import sys
import glob
import shutil

DENSITIES = [
    'mipmap-mdpi', 'mipmap-hdpi', 'mipmap-xhdpi',
    'mipmap-xxhdpi', 'mipmap-xxxhdpi',
]


def main(res_dir: str, icons_dir: str) -> None:
    if not os.path.isdir(res_dir):
        print('::error::cannot find android res dir: ' + res_dir)
        sys.exit(1)

    installed = 0
    for d in DENSITIES:
        src = os.path.join(icons_dir, d, 'ic_launcher.png')
        if not os.path.isfile(src):
            print('::warning::missing icon: ' + src)
            continue
        dst_dir = os.path.join(res_dir, d)
        os.makedirs(dst_dir, exist_ok=True)
        shutil.copyfile(src, os.path.join(dst_dir, 'ic_launcher.png'))
        shutil.copyfile(src, os.path.join(dst_dir, 'ic_launcher_round.png'))
        installed += 1
        print('installed icon -> ' + d)

    if installed == 0:
        print('::error::no icon installed')
        sys.exit(1)

    # 移除 adaptive 配置，否则 API 26+ 仍显示 Flutter 默认图标
    adv_dir = os.path.join(res_dir, 'mipmap-anydpi-v26')
    if os.path.isdir(adv_dir):
        for f in glob.glob(os.path.join(adv_dir, 'ic_launcher*.xml')):
            os.remove(f)
            print('removed adaptive config: ' + os.path.basename(f))

    print('icons installed OK (%d densities)' % installed)


if __name__ == '__main__':
    if len(sys.argv) != 3:
        print('usage: install_icons.py <res_dir> <icons_dir>')
        sys.exit(1)
    main(sys.argv[1], sys.argv[2])
