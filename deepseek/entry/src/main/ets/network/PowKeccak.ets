/**
 * 纯 ArkTS 32-bit split Keccak-f[1600] 实现，支持标准 SHA3-256 (startRound = 0)
 * 与 DeepSeekHashV1 (startRound = 1，跳过第 0 轮，仅执行第 1~23 轮)。
 */

const RC_LO: Uint32Array = new Uint32Array([
  0x00000001, 0x00008082, 0x0000808a, 0x80008000,
  0x0000808b, 0x80000001, 0x80008081, 0x00008009,
  0x0000008a, 0x00000088, 0x80008009, 0x8000000a,
  0x8000808b, 0x0000008b, 0x00008089, 0x00008003,
  0x00008002, 0x00000080, 0x0000800a, 0x8000000a,
  0x80008081, 0x00008080, 0x80000001, 0x80008008
]);

const RC_HI: Uint32Array = new Uint32Array([
  0x00000000, 0x00000000, 0x80000000, 0x80000000,
  0x00000000, 0x00000000, 0x80000000, 0x80000000,
  0x00000000, 0x00000000, 0x00000000, 0x00000000,
  0x00000000, 0x80000000, 0x80000000, 0x80000000,
  0x80000000, 0x80000000, 0x00000000, 0x80000000,
  0x80000000, 0x80000000, 0x00000000, 0x80000000
]);

const RHO_ROT: Int32Array = new Int32Array([
  0, 1, 62, 28, 27,
  36, 44, 6, 55, 20,
  3, 10, 43, 25, 39,
  41, 45, 15, 21, 8,
  18, 2, 61, 56, 14
]);

const PI_SRC: Int32Array = new Int32Array([
  0, 6, 12, 18, 24,
  3, 9, 10, 16, 22,
  1, 7, 13, 19, 20,
  4, 5, 11, 17, 23,
  2, 8, 14, 15, 21
]);

export function keccakF1600(
  sLo: Uint32Array,
  sHi: Uint32Array,
  startRound: number,
  cLo: Uint32Array,
  cHi: Uint32Array,
  dLo: Uint32Array,
  dHi: Uint32Array,
  bLo: Uint32Array,
  bHi: Uint32Array
): void {
  for (let round = startRound; round < 24; round++) {
    // Theta
    for (let x = 0; x < 5; x++) {
      cLo[x] = (sLo[x] ^ sLo[x + 5] ^ sLo[x + 10] ^ sLo[x + 15] ^ sLo[x + 20]) >>> 0;
      cHi[x] = (sHi[x] ^ sHi[x + 5] ^ sHi[x + 10] ^ sHi[x + 15] ^ sHi[x + 20]) >>> 0;
    }
    for (let x = 0; x < 5; x++) {
      const prev = (x + 4) % 5;
      const next = (x + 1) % 5;
      const nLo = cLo[next];
      const nHi = cHi[next];
      const rLo = ((nLo << 1) | (nHi >>> 31)) >>> 0;
      const rHi = ((nHi << 1) | (nLo >>> 31)) >>> 0;
      dLo[x] = (cLo[prev] ^ rLo) >>> 0;
      dHi[x] = (cHi[prev] ^ rHi) >>> 0;
    }
    for (let y = 0; y < 25; y += 5) {
      for (let x = 0; x < 5; x++) {
        sLo[y + x] = (sLo[y + x] ^ dLo[x]) >>> 0;
        sHi[y + x] = (sHi[y + x] ^ dHi[x]) >>> 0;
      }
    }

    // Rho + Pi
    for (let i = 0; i < 25; i++) {
      const srcIdx = PI_SRC[i];
      const lo = sLo[srcIdx];
      const hi = sHi[srcIdx];
      const rot = RHO_ROT[srcIdx];
      if (rot === 0) {
        bLo[i] = lo;
        bHi[i] = hi;
      } else if (rot < 32) {
        bLo[i] = ((lo << rot) | (hi >>> (32 - rot))) >>> 0;
        bHi[i] = ((hi << rot) | (lo >>> (32 - rot))) >>> 0;
      } else {
        const r = rot - 32;
        if (r === 0) {
          bLo[i] = hi;
          bHi[i] = lo;
        } else {
          bLo[i] = ((hi << r) | (lo >>> (32 - r))) >>> 0;
          bHi[i] = ((lo << r) | (hi >>> (32 - r))) >>> 0;
        }
      }
    }

    // Chi
    for (let y = 0; y < 25; y += 5) {
      for (let x = 0; x < 5; x++) {
        const x1 = (x + 1) % 5;
        const x2 = (x + 2) % 5;
        sLo[y + x] = (bLo[y + x] ^ ((~bLo[y + x1]) & bLo[y + x2])) >>> 0;
        sHi[y + x] = (bHi[y + x] ^ ((~bHi[y + x1]) & bHi[y + x2])) >>> 0;
      }
    }

    // Iota
    sLo[0] = (sLo[0] ^ RC_LO[round]) >>> 0;
    sHi[0] = (sHi[0] ^ RC_HI[round]) >>> 0;
  }
}

export class KeccakScratch {
  readonly sLo: Uint32Array = new Uint32Array(25);
  readonly sHi: Uint32Array = new Uint32Array(25);
  readonly cLo: Uint32Array = new Uint32Array(5);
  readonly cHi: Uint32Array = new Uint32Array(5);
  readonly dLo: Uint32Array = new Uint32Array(5);
  readonly dHi: Uint32Array = new Uint32Array(5);
  readonly bLo: Uint32Array = new Uint32Array(25);
  readonly bHi: Uint32Array = new Uint32Array(25);
}

function xorByteIntoState(sLo: Uint32Array, sHi: Uint32Array, pos: number, byteVal: number): void {
  const lane = pos >> 3;
  const shift = (pos & 3) << 3;
  if ((pos & 4) === 0) {
    sLo[lane] = (sLo[lane] ^ ((byteVal & 0xff) << shift)) >>> 0;
  } else {
    sHi[lane] = (sHi[lane] ^ ((byteVal & 0xff) << shift)) >>> 0;
  }
}

export function keccak256Into(
  input: Uint8Array,
  inputLen: number,
  startRound: number,
  scratch: KeccakScratch,
  outBytes: Uint8Array
): void {
  const sLo = scratch.sLo;
  const sHi = scratch.sHi;
  sLo.fill(0);
  sHi.fill(0);

  const rate = 136;
  let offset = 0;

  while (offset + rate <= inputLen) {
    for (let lane = 0; lane < 17; lane++) {
      const base = offset + (lane << 3);
      const lo =
        (input[base] |
          (input[base + 1] << 8) |
          (input[base + 2] << 16) |
          (input[base + 3] << 24)) >>> 0;
      const hi =
        (input[base + 4] |
          (input[base + 5] << 8) |
          (input[base + 6] << 16) |
          (input[base + 7] << 24)) >>> 0;
      sLo[lane] = (sLo[lane] ^ lo) >>> 0;
      sHi[lane] = (sHi[lane] ^ hi) >>> 0;
    }
    keccakF1600(
      sLo, sHi, startRound,
      scratch.cLo, scratch.cHi, scratch.dLo, scratch.dHi, scratch.bLo, scratch.bHi
    );
    offset += rate;
  }

  const rem = inputLen - offset;
  for (let i = 0; i < rem; i++) {
    xorByteIntoState(sLo, sHi, i, input[offset + i]);
  }
  xorByteIntoState(sLo, sHi, rem, 0x06);
  xorByteIntoState(sLo, sHi, rate - 1, 0x80);

  keccakF1600(
    sLo, sHi, startRound,
    scratch.cLo, scratch.cHi, scratch.dLo, scratch.dHi, scratch.bLo, scratch.bHi
  );

  for (let lane = 0; lane < 4; lane++) {
    const lo = sLo[lane];
    const hi = sHi[lane];
    const base = lane << 3;
    outBytes[base] = lo & 0xff;
    outBytes[base + 1] = (lo >>> 8) & 0xff;
    outBytes[base + 2] = (lo >>> 16) & 0xff;
    outBytes[base + 3] = (lo >>> 24) & 0xff;
    outBytes[base + 4] = hi & 0xff;
    outBytes[base + 5] = (hi >>> 8) & 0xff;
    outBytes[base + 6] = (hi >>> 16) & 0xff;
    outBytes[base + 7] = (hi >>> 24) & 0xff;
  }
}

export function keccak256Bytes(input: Uint8Array, startRound: number): Uint8Array {
  const scratch = new KeccakScratch();
  const out = new Uint8Array(32);
  keccak256Into(input, input.length, startRound, scratch, out);
  return out;
}

export function hexToBytes(hex: string): Uint8Array {
  const clean = hex.trim().toLowerCase();
  const len = clean.length >> 1;
  const out = new Uint8Array(len);
  for (let i = 0; i < len; i++) {
    const hi = parseHexNibble(clean.charCodeAt(i * 2));
    const lo = parseHexNibble(clean.charCodeAt(i * 2 + 1));
    out[i] = (hi << 4) | lo;
  }
  return out;
}

export function bytesToHex(bytes: Uint8Array): string {
  const chars = '0123456789abcdef';
  let out = '';
  for (let i = 0; i < bytes.length; i++) {
    const b = bytes[i];
    out += chars.charAt((b >>> 4) & 0x0f);
    out += chars.charAt(b & 0x0f);
  }
  return out;
}

function parseHexNibble(code: number): number {
  if (code >= 48 && code <= 57) {
    return code - 48;
  }
  if (code >= 97 && code <= 102) {
    return code - 87;
  }
  if (code >= 65 && code <= 70) {
    return code - 55;
  }
  return 0;
}
