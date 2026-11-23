#!/usr/bin/env python3
"""
Rebuild the release APP under low CPU load (default: 6 cores, low priority)
and sign it with the existing release signing material.

The keystore password is read from sign/keystore-password.txt and is never printed.
"""

import argparse
import pathlib
import subprocess
import sys

SCRIPT_DIR = pathlib.Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from build_low_cpu import apply_low_cpu_limits, run_hvigor_build  # noqa: E402

ROOT = SCRIPT_DIR.parent
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


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description='Build release APP under low CPU usage and sign with release cert.'
    )
    parser.add_argument(
        '--cores',
        type=int,
        default=6,
        help='Maximum CPU threads/cores to allow (default: 6)',
    )
    parser.add_argument(
        '--priority',
        choices=['low', 'below_normal'],
        default='low',
        help='Windows process priority class (default: low)',
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    required = [PASSWORD_FILE, KEYSTORE, CERT, PROFILE, SIGN_TOOL, JAVA]
    for path in required:
        if not path.exists():
            raise SystemExit(f'Missing file: {path}')

    password = PASSWORD_FILE.read_text(encoding='utf-8').strip()

    apply_low_cpu_limits(cores=args.cores, priority=args.priority)
    print('Building release APP (low-CPU mode)...')
    run_hvigor_build(
        mode='release',
        product='default',
        cores=args.cores,
        priority=args.priority,
        stop_daemon=False,
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
