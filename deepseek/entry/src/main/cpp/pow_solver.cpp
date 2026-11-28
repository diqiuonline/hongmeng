#include "napi/native_api.h"

#include <algorithm>
#include <atomic>
#include <cstdint>
#include <cstring>
#include <string>
#include <thread>
#include <vector>

namespace {

constexpr size_t KECCAK_RATE = 136;

constexpr uint64_t RC[24] = {
    0x0000000000000001ULL, 0x0000000000008082ULL, 0x800000000000808aULL, 0x8000000080008000ULL,
    0x000000000000808bULL, 0x0000000080000001ULL, 0x8000000080008081ULL, 0x8000000000008009ULL,
    0x000000000000008aULL, 0x0000000000000088ULL, 0x0000000080008009ULL, 0x000000008000000aULL,
    0x000000008000808bULL, 0x800000000000008bULL, 0x8000000000008089ULL, 0x8000000000008003ULL,
    0x8000000000008002ULL, 0x8000000000000080ULL, 0x000000000000800aULL, 0x800000008000000aULL,
    0x8000000080008081ULL, 0x8000000000008080ULL, 0x0000000080000001ULL, 0x8000000080008008ULL,
};

constexpr int RHO_ROT[25] = {
    0, 1, 62, 28, 27,
    36, 44, 6, 55, 20,
    3, 10, 43, 25, 39,
    41, 45, 15, 21, 8,
    18, 2, 61, 56, 14,
};

constexpr int PI_SRC[25] = {
    0, 6, 12, 18, 24,
    3, 9, 10, 16, 22,
    1, 7, 13, 19, 20,
    4, 5, 11, 17, 23,
    2, 8, 14, 15, 21,
};

inline uint64_t rotl64(uint64_t x, int r) {
    return (r == 0) ? x : ((x << r) | (x >> (64 - r)));
}

inline void xorByteIntoState(uint64_t s[25], size_t pos, uint8_t byteVal) {
    s[pos >> 3] ^= (static_cast<uint64_t>(byteVal) << ((pos & 7) << 3));
}

void keccakF1600Round1(uint64_t s[25]) {
    uint64_t c[5];
    uint64_t d[5];
    uint64_t b[25];

    for (int round = 1; round < 24; ++round) {
        for (int x = 0; x < 5; ++x) {
            c[x] = s[x] ^ s[x + 5] ^ s[x + 10] ^ s[x + 15] ^ s[x + 20];
        }
        d[0] = c[4] ^ rotl64(c[1], 1);
        d[1] = c[0] ^ rotl64(c[2], 1);
        d[2] = c[1] ^ rotl64(c[3], 1);
        d[3] = c[2] ^ rotl64(c[4], 1);
        d[4] = c[3] ^ rotl64(c[0], 1);

        for (int y = 0; y < 25; y += 5) {
            s[y] ^= d[0];
            s[y + 1] ^= d[1];
            s[y + 2] ^= d[2];
            s[y + 3] ^= d[3];
            s[y + 4] ^= d[4];
        }

        b[0] = s[0];
        for (int i = 1; i < 25; ++i) {
            const int srcIdx = PI_SRC[i];
            b[i] = rotl64(s[srcIdx], RHO_ROT[srcIdx]);
        }

        for (int y = 0; y < 25; y += 5) {
            const uint64_t b0 = b[y];
            const uint64_t b1 = b[y + 1];
            const uint64_t b2 = b[y + 2];
            const uint64_t b3 = b[y + 3];
            const uint64_t b4 = b[y + 4];
            s[y] = b0 ^ ((~b1) & b2);
            s[y + 1] = b1 ^ ((~b2) & b3);
            s[y + 2] = b2 ^ ((~b3) & b4);
            s[y + 3] = b3 ^ ((~b4) & b0);
            s[y + 4] = b4 ^ ((~b0) & b1);
        }

        s[0] ^= RC[round];
    }
}

int parseHexNibble(char ch) {
    if (ch >= '0' && ch <= '9') {
        return ch - '0';
    }
    if (ch >= 'a' && ch <= 'f') {
        return ch - 'a' + 10;
    }
    if (ch >= 'A' && ch <= 'F') {
        return ch - 'A' + 10;
    }
    return -1;
}

bool parseTargetHex(const std::string& rawHex, uint64_t outTarget[4]) {
    size_t start = 0;
    size_t end = rawHex.size();
    while (start < end && (rawHex[start] == ' ' || rawHex[start] == '\t' || rawHex[start] == '\r' || rawHex[start] == '\n')) {
        ++start;
    }
    while (end > start && (rawHex[end - 1] == ' ' || rawHex[end - 1] == '\t' || rawHex[end - 1] == '\r' || rawHex[end - 1] == '\n')) {
        --end;
    }
    if (end - start != 64) {
        return false;
    }

    uint8_t bytes[32];
    for (size_t i = 0; i < 32; ++i) {
        const int hi = parseHexNibble(rawHex[start + i * 2]);
        const int lo = parseHexNibble(rawHex[start + i * 2 + 1]);
        if (hi < 0 || lo < 0) {
            return false;
        }
        bytes[i] = static_cast<uint8_t>((hi << 4) | lo);
    }

    for (size_t lane = 0; lane < 4; ++lane) {
        const size_t base = lane * 8;
        outTarget[lane] =
            static_cast<uint64_t>(bytes[base]) |
            (static_cast<uint64_t>(bytes[base + 1]) << 8) |
            (static_cast<uint64_t>(bytes[base + 2]) << 16) |
            (static_cast<uint64_t>(bytes[base + 3]) << 24) |
            (static_cast<uint64_t>(bytes[base + 4]) << 32) |
            (static_cast<uint64_t>(bytes[base + 5]) << 40) |
            (static_cast<uint64_t>(bytes[base + 6]) << 48) |
            (static_cast<uint64_t>(bytes[base + 7]) << 56);
    }
    return true;
}

inline int encodeDigitsAsc(int64_t nonce, uint8_t digits[24]) {
    if (nonce == 0) {
        digits[0] = '0';
        return 1;
    }
    uint8_t rev[24];
    int count = 0;
    int64_t n = nonce;
    while (n > 0) {
        rev[count++] = static_cast<uint8_t>('0' + (n % 10));
        n /= 10;
    }
    for (int i = 0; i < count; ++i) {
        digits[i] = rev[count - 1 - i];
    }
    return count;
}

int64_t solveDeepSeekHashV1Native(const std::string& prefix, const std::string& targetHex, int64_t maxNonce) {
    if (maxNonce < 0) {
        return -1;
    }

    uint64_t target[4];
    if (!parseTargetHex(targetHex, target)) {
        return -1;
    }

    uint64_t baseState[25] = {};
    const size_t prefixLen = prefix.size();
    size_t offset = 0;

    while (offset + KECCAK_RATE <= prefixLen) {
        for (size_t lane = 0; lane < 17; ++lane) {
            const size_t p = offset + (lane << 3);
            uint64_t w =
                static_cast<uint64_t>(static_cast<uint8_t>(prefix[p])) |
                (static_cast<uint64_t>(static_cast<uint8_t>(prefix[p + 1])) << 8) |
                (static_cast<uint64_t>(static_cast<uint8_t>(prefix[p + 2])) << 16) |
                (static_cast<uint64_t>(static_cast<uint8_t>(prefix[p + 3])) << 24) |
                (static_cast<uint64_t>(static_cast<uint8_t>(prefix[p + 4])) << 32) |
                (static_cast<uint64_t>(static_cast<uint8_t>(prefix[p + 5])) << 40) |
                (static_cast<uint64_t>(static_cast<uint8_t>(prefix[p + 6])) << 48) |
                (static_cast<uint64_t>(static_cast<uint8_t>(prefix[p + 7])) << 56);
            baseState[lane] ^= w;
        }
        keccakF1600Round1(baseState);
        offset += KECCAK_RATE;
    }

    const size_t prefixRemLen = prefixLen - offset;
    for (size_t i = 0; i < prefixRemLen; ++i) {
        xorByteIntoState(baseState, i, static_cast<uint8_t>(prefix[offset + i]));
    }

    // Fast path: trailing prefix bytes + up to 20 nonce digits always fit below byte 135,
    // so 0x06 and final 0x80 never collide and every nonce hashes in a single permutation.
    const bool useFastPath = (prefixRemLen + 20 < KECCAK_RATE);
    if (useFastPath) {
        baseState[16] ^= 0x8000000000000000ULL;
    }

    unsigned int hwThreads = std::thread::hardware_concurrency();
    if (hwThreads == 0) {
        hwThreads = 4;
    }
    unsigned int workerCount = (maxNonce < 4096) ? 1 : std::min<unsigned int>(8, std::max<unsigned int>(2, hwThreads));

    constexpr int64_t BATCH_SIZE = 4096;
    std::atomic<int64_t> nextNonce{0};
    std::atomic<bool> found{false};
    std::atomic<int64_t> answer{-1};

    auto workerLoop = [&]() {
        uint64_t s[25];
        uint8_t digits[24];

        while (!found.load(std::memory_order_relaxed)) {
            const int64_t start = nextNonce.fetch_add(BATCH_SIZE, std::memory_order_relaxed);
            if (start > maxNonce) {
                break;
            }
            const int64_t end = std::min<int64_t>(maxNonce, start + BATCH_SIZE - 1);

            for (int64_t nonce = start; nonce <= end; ++nonce) {
                if ((nonce & 255) == 0 && found.load(std::memory_order_relaxed)) {
                    return;
                }

                std::memcpy(s, baseState, sizeof(s));
                const int digitCount = encodeDigitsAsc(nonce, digits);

                if (useFastPath) {
                    size_t pos = prefixRemLen;
                    for (int i = 0; i < digitCount; ++i) {
                        xorByteIntoState(s, pos++, digits[i]);
                    }
                    xorByteIntoState(s, pos, 0x06);
                    keccakF1600Round1(s);
                } else {
                    size_t pos = prefixRemLen;
                    for (int i = 0; i < digitCount; ++i) {
                        xorByteIntoState(s, pos++, digits[i]);
                        if (pos == KECCAK_RATE) {
                            keccakF1600Round1(s);
                            pos = 0;
                        }
                    }
                    xorByteIntoState(s, pos, 0x06);
                    xorByteIntoState(s, KECCAK_RATE - 1, 0x80);
                    keccakF1600Round1(s);
                }

                if (s[0] == target[0] && s[1] == target[1] && s[2] == target[2] && s[3] == target[3]) {
                    int64_t expected = -1;
                    if (answer.compare_exchange_strong(expected, nonce, std::memory_order_acq_rel)) {
                        found.store(true, std::memory_order_relaxed);
                    }
                    return;
                }
            }
        }
    };

    if (workerCount <= 1) {
        workerLoop();
        return answer.load(std::memory_order_acquire);
    }

    std::vector<std::thread> threads;
    threads.reserve(workerCount);
    for (unsigned int i = 0; i < workerCount; ++i) {
        threads.emplace_back(workerLoop);
    }
    for (auto& t : threads) {
        t.join();
    }
    return answer.load(std::memory_order_acquire);
}

struct SolvePowJob {
    napi_async_work work = nullptr;
    napi_deferred deferred = nullptr;
    std::string prefix;
    std::string targetHex;
    int64_t maxNonce = -1;
    int64_t result = -1;
};

void ExecuteSolvePow(napi_env /*env*/, void* data) {
    auto* job = static_cast<SolvePowJob*>(data);
    job->result = solveDeepSeekHashV1Native(job->prefix, job->targetHex, job->maxNonce);
}

void CompleteSolvePow(napi_env env, napi_status status, void* data) {
    auto* job = static_cast<SolvePowJob*>(data);
    napi_value val = nullptr;
    if (status == napi_ok) {
        napi_create_double(env, static_cast<double>(job->result), &val);
        napi_resolve_deferred(env, job->deferred, val);
    } else {
        napi_create_double(env, -1.0, &val);
        napi_resolve_deferred(env, job->deferred, val);
    }
    napi_delete_async_work(env, job->work);
    delete job;
}

bool readUtf8String(napi_env env, napi_value value, std::string& out) {
    size_t len = 0;
    if (napi_get_value_string_utf8(env, value, nullptr, 0, &len) != napi_ok) {
        return false;
    }
    out.resize(len);
    if (len == 0) {
        return true;
    }
    size_t copied = 0;
    if (napi_get_value_string_utf8(env, value, &out[0], len + 1, &copied) != napi_ok) {
        return false;
    }
    out.resize(copied);
    return true;
}

napi_value SolveDeepSeekHashV1(napi_env env, napi_callback_info info) {
    size_t argc = 3;
    napi_value args[3] = {nullptr, nullptr, nullptr};
    if (napi_get_cb_info(env, info, &argc, args, nullptr, nullptr) != napi_ok || argc < 3) {
        napi_throw_type_error(env, nullptr, "Expected 3 arguments: (prefix, targetHex, maxNonce)");
        return nullptr;
    }

    std::string prefix;
    std::string targetHex;
    double maxNonceNum = -1.0;
    if (!readUtf8String(env, args[0], prefix) ||
        !readUtf8String(env, args[1], targetHex) ||
        napi_get_value_double(env, args[2], &maxNonceNum) != napi_ok) {
        napi_throw_type_error(env, nullptr, "Invalid arguments for solveDeepSeekHashV1");
        return nullptr;
    }

    auto* job = new SolvePowJob();
    job->prefix = std::move(prefix);
    job->targetHex = std::move(targetHex);
    job->maxNonce = (maxNonceNum >= 0.0) ? static_cast<int64_t>(maxNonceNum) : -1;

    napi_value promise = nullptr;
    if (napi_create_promise(env, &job->deferred, &promise) != napi_ok) {
        delete job;
        return nullptr;
    }

    napi_value resourceName = nullptr;
    napi_create_string_utf8(env, "SolveDeepSeekHashV1", NAPI_AUTO_LENGTH, &resourceName);

    if (napi_create_async_work(env, nullptr, resourceName, ExecuteSolvePow, CompleteSolvePow, job, &job->work) != napi_ok) {
        napi_value fallback = nullptr;
        napi_create_double(env, -1.0, &fallback);
        napi_resolve_deferred(env, job->deferred, fallback);
        delete job;
        return promise;
    }

    if (napi_queue_async_work_with_qos(env, job->work, napi_qos_user_initiated) != napi_ok) {
        napi_delete_async_work(env, job->work);
        napi_value fallback = nullptr;
        napi_create_double(env, -1.0, &fallback);
        napi_resolve_deferred(env, job->deferred, fallback);
        delete job;
        return promise;
    }

    return promise;
}

napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor desc[] = {
        {"solveDeepSeekHashV1", nullptr, SolveDeepSeekHashV1, nullptr, nullptr, nullptr, napi_default, nullptr}
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}

napi_module g_powSolverModule = {
    1,
    0,
    nullptr,
    nullptr,
    "pow_solver",
    nullptr,
    {0},
};

} // namespace

extern "C" __attribute__((constructor)) void RegisterPowSolverModule(void) {
    g_powSolverModule.nm_register_func = Init;
    napi_module_register(&g_powSolverModule);
}
