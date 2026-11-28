#!/usr/bin/env python3
"""
Low-CPU HarmonyOS build runner for deepseek.

Applies Windows CPU affinity mask (default: 4 cores -> 0x0F) and low process priority
to the current Python process before spawning hvigorw/node/java child processes, so
the entire compilation tree inherits the CPU cap without starving interactive work.
"""

import argparse
import ctypes
import os
import pathlib
import subprocess

ROOT = pathlib.Path(__file__).resolve().parent.parent
STUDIO_DIR = pathlib.Path(r'D:/Program Files/Huawei/DevEco Studio')
NODE = STUDIO_DIR / 'tools' / 'node' / 'node.exe'
HVIGORW = STUDIO_DIR / 'tools' / 'hvigor' / 'bin' / 'hvigorw.js'
SDK_HOME = STUDIO_DIR / 'sdk'
JAVA_BIN = STUDIO_DIR / 'jbr' / 'bin'

IDLE_PRIORITY_CLASS = 0x00000040
BELOW_NORMAL_PRIORITY_CLASS = 0x00004000
PRIORITY_FLAGS = {
    'low': IDLE_PRIORITY_CLASS,
    'below_normal': BELOW_NORMAL_PRIORITY_CLASS,
}


def apply_low_cpu_limits(cores: int = 4, priority: str = 'low') -> tuple[int, int]:
    """Limit the current process (and future child processes) to N CPU cores and low priority."""
    cpu_total = os.cpu_count() or cores
    effective_cores = max(1, min(cores, cpu_total))
    mask = (1 << effective_cores) - 1

    if priority not in PRIORITY_FLAGS:
        raise ValueError(f'Unsupported priority "{priority}", expected one of {list(PRIORITY_FLAGS)}')
    priority_flag = PRIORITY_FLAGS[priority]

    if os.name != 'nt':
        print(f'Non-Windows host detected; skipping Win32 affinity/priority (requested {effective_cores} cores).')
        return effective_cores, mask

    kernel32 = ctypes.WinDLL('kernel32', use_last_error=True)
    kernel32.GetCurrentProcess.restype = ctypes.c_void_p
    kernel32.SetProcessAffinityMask.argtypes = [ctypes.c_void_p, ctypes.c_size_t]
    kernel32.SetProcessAffinityMask.restype = ctypes.c_int
    kernel32.SetPriorityClass.argtypes = [ctypes.c_void_p, ctypes.c_uint32]
    kernel32.SetPriorityClass.restype = ctypes.c_int

    handle = kernel32.GetCurrentProcess()
    if not kernel32.SetProcessAffinityMask(handle, mask):
        err = ctypes.get_last_error()
        raise OSError(err, f'SetProcessAffinityMask(mask=0x{mask:X}) failed with Win32 error {err}')

    if not kernel32.SetPriorityClass(handle, priority_flag):
        err = ctypes.get_last_error()
        raise OSError(err, f'SetPriorityClass(flag=0x{priority_flag:X}) failed with Win32 error {err}')

    print(
        f'Applied CPU limit: {effective_cores}/{cpu_total} cores (affinity mask=0x{mask:X}), '
        f'priority={priority}'
    )
    return effective_cores, mask


def build_hvigor_env() -> dict[str, str]:
    """Build environment variables matching devecocli (DEVECO_SDK_HOME + JBR PATH)."""
    env = os.environ.copy()
    if not env.get('DEVECO_SDK_HOME'):
        env['DEVECO_SDK_HOME'] = str(SDK_HOME)
    extra_paths = [str(JAVA_BIN), str(NODE.parent)]
    current_path = env.get('PATH', '')
    env['PATH'] = os.pathsep.join(extra_paths + ([current_path] if current_path else []))
    return env


def stop_hvigor_daemons() -> None:
    """Stop any pre-existing Hvigor daemons that may have started without CPU limits."""
    if not NODE.exists() or not HVIGORW.exists():
        return
    subprocess.run(
        [str(NODE), str(HVIGORW), '--stop-daemon-all'],
        cwd=ROOT,
        env=build_hvigor_env(),
        check=False,
    )


def run_hvigor_build(
    mode: str = 'debug',
    product: str = 'default',
    cores: int = 4,
    priority: str = 'low',
    stop_daemon: bool = False,
) -> None:
    """Run hvigor assembleApp with --no-parallel --no-daemon under CPU and priority limits."""
    for path in (NODE, HVIGORW, SDK_HOME):
        if not path.exists():
            raise SystemExit(f'Missing DevEco tool/SDK path: {path}')

    apply_low_cpu_limits(cores=cores, priority=priority)
    env = build_hvigor_env()
    if stop_daemon:
        stop_hvigor_daemons()

    cmd = [
        str(NODE),
        str(HVIGORW),
        'assembleApp',
        '-p',
        f'product={product}',
        '-p',
        f'buildMode={mode}',
        '--analyze=normal',
        '--no-parallel',
        '--no-daemon',
        '--incremental',
    ]
    print(f'Running low-CPU hvigor build ({mode}, product={product})...')
    subprocess.run(cmd, cwd=ROOT, env=env, check=True)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description='Build deepseek with capped CPU cores and low process priority.'
    )
    parser.add_argument(
        '--mode',
        choices=['debug', 'release'],
        default='debug',
        help='Build mode (default: debug)',
    )
    parser.add_argument(
        '--product',
        default='default',
        help='Product name defined in build-profile.json5 (default: default)',
    )
    parser.add_argument(
        '--cores',
        type=int,
        default=4,
        help='Maximum CPU threads/cores to allow (default: 4)',
    )
    parser.add_argument(
        '--priority',
        choices=['low', 'below_normal'],
        default='low',
        help='Windows process priority class (default: low)',
    )
    parser.add_argument(
        '--stop-daemon',
        action='store_true',
        help='Stop existing Hvigor daemons before building',
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    run_hvigor_build(
        mode=args.mode,
        product=args.product,
        cores=args.cores,
        priority=args.priority,
        stop_daemon=args.stop_daemon,
    )


if __name__ == '__main__':
    main()
