#!/usr/bin/env python3
"""
Checks that all 64-bit ELF shared libraries (.so) in Android jniLibs
are 16 KB page-size compatible for Android 15+.

Specifically verifies:
1. Every PT_LOAD segment has p_align >= 0x4000 (16 KB).
2. p_offset % 0x4000 == p_vaddr % 0x4000 for each PT_LOAD segment.
3. If PT_GNU_RELRO exists, its end address (p_vaddr + p_memsz) % 0x4000 == 0.
"""

import os
import subprocess
import sys

def check_library(file_path):
    try:
        out = subprocess.check_output(['readelf', '-W', '-l', file_path], text=True)
    except Exception as e:
        return False, [f"Failed to run readelf: {e}"]

    errors = []
    loads = []
    relro = None

    for line in out.splitlines():
        line = line.strip()
        if line.startswith('LOAD'):
            parts = line.split()
            # Format: LOAD Offset VirtAddr PhysAddr FileSiz MemSiz [Flags...] Align
            off = int(parts[1], 16)
            vaddr = int(parts[2], 16)
            filesiz = int(parts[4], 16)
            memsiz = int(parts[5], 16)
            align = int(parts[-1], 16)
            loads.append((off, vaddr, filesiz, memsiz, align))
        elif line.startswith('GNU_RELRO'):
            parts = line.split()
            off = int(parts[1], 16)
            vaddr = int(parts[2], 16)
            filesiz = int(parts[4], 16)
            memsiz = int(parts[5], 16)
            align = int(parts[-1], 16)
            relro = (off, vaddr, filesiz, memsiz, align)

    if not loads:
        errors.append("No PT_LOAD segments found.")

    for i, (off, vaddr, filesiz, memsiz, align) in enumerate(loads):
        if align < 0x4000:
            errors.append(f"LOAD[{i}] align {hex(align)} is less than 0x4000 (16 KB)")
        if (off % 0x4000) != (vaddr % 0x4000):
            errors.append(
                f"LOAD[{i}] offset {hex(off)} % 16KB ({hex(off % 0x4000)}) != "
                f"vaddr {hex(vaddr)} % 16KB ({hex(vaddr % 0x4000)})"
            )

    if relro:
        off, vaddr, filesiz, memsiz, align = relro
        end = vaddr + memsiz
        if end % 0x4000 != 0:
            errors.append(
                f"PT_GNU_RELRO end address {hex(end)} is not 16 KB aligned "
                f"(end % 0x4000 = {hex(end % 0x4000)})"
            )

    return (len(errors) == 0), errors


def main():
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    jni_libs_dir = os.path.join(base_dir, 'android', 'app', 'src', 'main', 'jniLibs')

    target_abis = ['arm64-v8a', 'x86_64']
    all_passed = True
    tested_count = 0

    for abi in target_abis:
        abi_dir = os.path.join(jni_libs_dir, abi)
        if not os.path.isdir(abi_dir):
            continue

        for f in sorted(os.listdir(abi_dir)):
            if not f.endswith('.so'):
                continue
            lib_path = os.path.join(abi_dir, f)
            rel_path = os.path.relpath(lib_path, base_dir)
            passed, errors = check_library(lib_path)
            tested_count += 1
            if passed:
                print(f"✓ {rel_path}: 16 KB ALIGNED")
            else:
                all_passed = False
                print(f"✗ {rel_path}: UNALIGNED")
                for err in errors:
                    print(f"    - {err}")

    if tested_count == 0:
        print("No 64-bit shared libraries found to check.")
        sys.exit(1)

    if all_passed:
        print(f"\nAll {tested_count} 64-bit libraries are 16 KB page-size compatible!")
        sys.exit(0)
    else:
        print(f"\nFound alignment errors in 64-bit libraries.")
        sys.exit(1)


if __name__ == '__main__':
    main()
