#!/usr/bin/env python3
"""
Rebuild the release APP and sign it with the existing release signing material.

The keystore password is read from sign/keystore-password.txt and is never printed.
"""

import pathlib
import subprocess

ROOT = pathlib.Path(__file__).resolve().parent.parent
SIGN_DIR = ROOT / 'sign'
UNSIGNED_APP = ROOT / 'build' / 'outputs' / 'default' / 'lkong-harmony-default-unsigned.app'
SIGNED_APP = ROOT / 'build' / 'outputs' / 'default' / 'lkong-harmony-default-signed.app'
PASSWORD_FILE = SIGN_DIR / 'keystore-password.txt'
KEYSTORE = SIGN_DIR / 'lkong.p12'
CERT = SIGN_DIR / 'lkong.cer'
PROFILE = SIGN_DIR / 'lkongRelease.p7b'
SIGN_TOOL = pathlib.Path(
    r'D:/Program Files/Huawei/DevEco Studio/sdk/default/openharmony/toolchains/lib/hap-sign-tool.jar'
)
JAVA = pathlib.Path(r'D:/Program Files/Huawei/DevEco Studio/jbr/bin/java.exe')


def main() -> None:
    required = [PASSWORD_FILE, KEYSTORE, CERT, PROFILE, SIGN_TOOL, JAVA]
    for path in required:
        if not path.exists():
            raise SystemExit(f'Missing file: {path}')

    password = PASSWORD_FILE.read_text(encoding='utf-8').strip()

    print('Building release APP...')
    subprocess.run(
        'devecocli build --product default --build-mode release',
        cwd=ROOT,
        check=True,
        shell=True,
    )

    if not UNSIGNED_APP.exists():
        raise SystemExit(f'Unsigned APP not found: {UNSIGNED_APP}')

    if SIGNED_APP.exists():
        SIGNED_APP.unlink()

    print('Signing APP...')
    cmd = [
        str(JAVA),
        '-jar',
        str(SIGN_TOOL),
        'sign-app',
        '-mode',
        'localSign',
        '-keyAlias',
        'lkong_key',
        '-appCertFile',
        str(CERT),
        '-profileFile',
        str(PROFILE),
        '-inFile',
        str(UNSIGNED_APP),
        '-signAlg',
        'SHA256withECDSA',
        '-keystoreFile',
        str(KEYSTORE),
        '-outFile',
        str(SIGNED_APP),
        '-pwdInputMode',
        '0',
        '-keyPwd',
        password,
        '-keystorePwd',
        password,
    ]
    subprocess.run(cmd, cwd=ROOT, check=True)
    print(f'Signed APP: {SIGNED_APP}')


if __name__ == '__main__':
    main()