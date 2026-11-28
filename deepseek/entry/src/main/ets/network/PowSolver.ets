import { taskpool, util } from '@kit.ArkTS';
import powNative from 'libpow_solver.so';
import { ApiError, ErrorKind } from '../model/ApiErrors';
import { PowChallenge } from '../model/ChatModels';
import { hexToBytes, keccak256IntoState, KeccakScratch } from './PowKeccak';

@Concurrent
export function solvePowSlice(
  prefix: string,
  targetHex: string,
  startNonce: number,
  endNonce: number,
  fromTaskPool: boolean = false
): number {
  const encoder = util.TextEncoder.create('utf-8');
  const prefixBytes = prefix.length === 0 ? new Uint8Array(0) : encoder.encodeInto(prefix);
  const targetBytes = hexToBytes(targetHex);
  if (targetBytes.length !== 32) {
    return -1;
  }

  const tLo = new Uint32Array(4);
  const tHi = new Uint32Array(4);
  for (let lane = 0; lane < 4; lane++) {
    const b = lane << 3;
    tLo[lane] =
      (targetBytes[b] |
        (targetBytes[b + 1] << 8) |
        (targetBytes[b + 2] << 16) |
        (targetBytes[b + 3] << 24)) >>> 0;
    tHi[lane] =
      (targetBytes[b + 4] |
        (targetBytes[b + 5] << 8) |
        (targetBytes[b + 6] << 16) |
        (targetBytes[b + 7] << 24)) >>> 0;
  }
  const tLo0 = tLo[0];
  const tHi0 = tHi[0];
  const tLo1 = tLo[1];
  const tHi1 = tHi[1];
  const tLo2 = tLo[2];
  const tHi2 = tHi[2];
  const tLo3 = tLo[3];
  const tHi3 = tHi[3];

  const scratch = new KeccakScratch();
  const sLo = scratch.sLo;
  const sHi = scratch.sHi;
  const buf = new Uint8Array(prefixBytes.length + 24);
  buf.set(prefixBytes, 0);
  const digitBuf = new Uint8Array(24);
  const prefixLen = prefixBytes.length;

  for (let nonce = startNonce; nonce <= endNonce; nonce++) {
    if (fromTaskPool && (nonce & 255) === 0 && taskpool.Task.isCanceled()) {
      return -1;
    }

    let n = nonce;
    let digitCount = 0;
    if (n === 0) {
      digitBuf[0] = 48;
      digitCount = 1;
    } else {
      while (n > 0) {
        digitBuf[digitCount] = 48 + (n % 10);
        digitCount++;
        n = Math.floor(n / 10);
      }
    }
    for (let i = 0; i < digitCount; i++) {
      buf[prefixLen + i] = digitBuf[digitCount - 1 - i];
    }

    keccak256IntoState(buf, prefixLen + digitCount, 1, scratch);

    if (
      sLo[0] === tLo0 &&
      sHi[0] === tHi0 &&
      sLo[1] === tLo1 &&
      sHi[1] === tHi1 &&
      sLo[2] === tLo2 &&
      sHi[2] === tHi2 &&
      sLo[3] === tLo3 &&
      sHi[3] === tHi3
    ) {
      return nonce;
    }
  }
  return -1;
}

interface PowResponsePayload {
  algorithm: string;
  challenge: string;
  salt: string;
  answer: number;
  signature: string;
  target_path: string;
}

export class PowSolver {
  static async solve(challenge: PowChallenge): Promise<string> {
    if (challenge.algorithm !== 'DeepSeekHashV1') {
      throw new ApiError(
        ErrorKind.POW_FAILED,
        `暂不支持的 PoW 算法（${challenge.algorithm}），请切换网页应急模式完成对话。`
      );
    }

    const prefix = `${challenge.salt}_${challenge.expireAt}_`;
    const maxNonce = Math.max(1, Math.ceil(challenge.difficulty));
    let answer = -1;
    try {
      answer = await powNative.solveDeepSeekHashV1(prefix, challenge.challenge, maxNonce);
    } catch (_nativeErr) {
      answer = await PowSolver.findAnswerParallel(prefix, challenge.challenge, maxNonce);
    }

    if (answer < 0) {
      throw new ApiError(ErrorKind.POW_FAILED, '安全计算校验未命中，请重试或切换网页模式。');
    }

    const payload: PowResponsePayload = {
      algorithm: challenge.algorithm,
      challenge: challenge.challenge,
      salt: challenge.salt,
      answer: Math.floor(answer),
      signature: challenge.signature,
      target_path: challenge.targetPath
    };

    const json = JSON.stringify(payload);
    const encoder = util.TextEncoder.create('utf-8');
    const bytes = encoder.encodeInto(json);
    const base64 = new util.Base64Helper().encodeToStringSync(bytes);
    return base64.replace(/\r/g, '').replace(/\n/g, '');
  }

  private static async findAnswerParallel(
    prefix: string,
    targetHex: string,
    maxNonce: number
  ): Promise<number> {
    if (maxNonce < 2000) {
      return solvePowSlice(prefix, targetHex, 0, maxNonce, false);
    }

    const workers = 6;
    const chunkSize = Math.ceil((maxNonce + 1) / workers);
    const tasks: Array<taskpool.Task> = [];

    for (let i = 0; i < workers; i++) {
      const start = i * chunkSize;
      if (start > maxNonce) {
        break;
      }
      const end = Math.min(maxNonce, (i + 1) * chunkSize - 1);
      tasks.push(new taskpool.Task(solvePowSlice, prefix, targetHex, start, end, true));
    }

    try {
      return await new Promise<number>((resolve) => {
        let settled = false;
        let finishedCount = 0;
        const total = tasks.length;

        for (const task of tasks) {
          taskpool.execute(task, taskpool.Priority.HIGH).then((res: Object) => {
            const answer = typeof res === 'number' ? res : -1;
            if (!settled && answer >= 0) {
              settled = true;
              for (const other of tasks) {
                if (other !== task) {
                  try {
                    taskpool.cancel(other);
                  } catch (cancelErr) {
                    // 忽略正在执行或已完成的任务取消异常。
                  }
                }
              }
              resolve(answer);
              return;
            }
            finishedCount++;
            if (!settled && finishedCount >= total) {
              settled = true;
              resolve(-1);
            }
          }).catch(() => {
            finishedCount++;
            if (!settled && finishedCount >= total) {
              settled = true;
              resolve(-1);
            }
          });
        }
      });
    } catch (err) {
      return solvePowSlice(prefix, targetHex, 0, maxNonce, false);
    }
  }
}
