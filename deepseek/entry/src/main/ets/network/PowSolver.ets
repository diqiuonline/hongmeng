import { taskpool, util } from '@kit.ArkTS';
import { ApiError, ErrorKind } from '../model/ApiErrors';
import { PowChallenge } from '../model/ChatModels';
import { hexToBytes, keccak256Into, KeccakScratch } from './PowKeccak';

@Concurrent
export function solvePowSlice(
  prefix: string,
  targetHex: string,
  startNonce: number,
  endNonce: number
): number {
  const encoder = util.TextEncoder.create('utf-8');
  const prefixBytes = prefix.length === 0 ? new Uint8Array(0) : encoder.encodeInto(prefix);
  const targetBytes = hexToBytes(targetHex);
  if (targetBytes.length !== 32) {
    return -1;
  }

  const scratch = new KeccakScratch();
  const outBytes = new Uint8Array(32);
  const buf = new Uint8Array(prefixBytes.length + 24);
  buf.set(prefixBytes, 0);
  const digitBuf = new Uint8Array(24);
  const prefixLen = prefixBytes.length;

  for (let nonce = startNonce; nonce <= endNonce; nonce++) {
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

    keccak256Into(buf, prefixLen + digitCount, 1, scratch, outBytes);

    let matched = true;
    for (let i = 0; i < 32; i++) {
      if (outBytes[i] !== targetBytes[i]) {
        matched = false;
        break;
      }
    }
    if (matched) {
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
    const answer = await PowSolver.findAnswerParallel(prefix, challenge.challenge, maxNonce);

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
      return solvePowSlice(prefix, targetHex, 0, maxNonce);
    }

    const workers = 4;
    const chunkSize = Math.ceil((maxNonce + 1) / workers);
    const tasks: Array<taskpool.Task> = [];

    for (let i = 0; i < workers; i++) {
      const start = i * chunkSize;
      if (start > maxNonce) {
        break;
      }
      const end = Math.min(maxNonce, (i + 1) * chunkSize - 1);
      tasks.push(new taskpool.Task(solvePowSlice, prefix, targetHex, start, end));
    }

    try {
      return await new Promise<number>((resolve) => {
        let settled = false;
        let finishedCount = 0;
        const total = tasks.length;

        for (const task of tasks) {
          taskpool.execute(task).then((res: Object) => {
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
      return solvePowSlice(prefix, targetHex, 0, maxNonce);
    }
  }
}
