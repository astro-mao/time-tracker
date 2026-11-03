#!/usr/bin/env python3
"""把「固定签名」配置注入 Flutter 生成的 android/app/build.gradle。

解决"每次更新都提示失败、要卸载重装"的问题：
Flutter 默认用随机的 debug 密钥给 release 包签名，每次 CI 构建环境都是全新的，
密钥随机生成 → 签名每次都不一样 → 安卓拒绝覆盖安装。
本脚本改用仓库里固定的 release.p12 密钥签名，签名从此稳定。

用法: python3 inject_signing.py <android/app/build.gradle 路径>
"""
import re
import sys

STORE_PASS = "timetracker2024"
KEY_ALIAS = "timetracker"

# Groovy DSL 的 signingConfigs 块（Flutter 3.24.x 生成的是 Groovy 版 build.gradle）
SIGNING_BLOCK = f"""
    signingConfigs {{
        release {{
            storeFile file("release.p12")
            storePassword "{STORE_PASS}"
            keyAlias "{KEY_ALIAS}"
            keyPassword "{STORE_PASS}"
        }}
    }}
"""


def main(path: str) -> None:
    with open(path, encoding="utf-8") as f:
        src = f.read()

    if "signingConfigs {" in src:
        print("signingConfigs already present, skip insert")
    else:
        m = re.search(r"android\s*\{", src)
        if not m:
            print("::error::cannot find 'android {' in build.gradle")
            sys.exit(1)
        src = src[: m.end()] + SIGNING_BLOCK + src[m.end():]

    # 把 release 构建的 debug 签名替换为固定 release 签名
    if "signingConfig = signingConfigs.debug" in src:
        src = src.replace(
            "signingConfig = signingConfigs.debug",
            "signingConfig = signingConfigs.release",
        )
    elif "signingConfig signingConfigs.debug" in src:  # 无 '=' 写法
        src = src.replace(
            "signingConfig signingConfigs.debug",
            "signingConfig signingConfigs.release",
        )
    else:
        print("::warning::did not find 'signingConfig ... debug' to replace")

    with open(path, "w", encoding="utf-8") as f:
        f.write(src)
    print("signing injected OK")


if __name__ == "__main__":
    main(sys.argv[1])
