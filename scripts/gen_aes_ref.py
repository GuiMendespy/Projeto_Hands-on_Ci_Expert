#!/usr/bin/env python3
"""Modelo de referência AES-128 (FIPS-197) em Python.

Gera: S-box / InvS-box (RTL) e vetores intermediários (tb/vectors/aes_vectors.svh).
Convenção de estado: byte n em [127-8n -: 8]; s[r][c], r = n mod 4, c = n div 4.
"""
import os
import random

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def xtime(a):
    return ((a << 1) ^ 0x11B) & 0xFF if a & 0x80 else (a << 1) & 0xFF


def gmul(a, b):
    r = 0
    while b:
        if b & 1:
            r ^= a
        a = xtime(a)
        b >>= 1
    return r


def ginv(a):
    if a == 0:
        return 0
    return next(b for b in range(1, 256) if gmul(a, b) == 1)


def rotl8(x, n):
    return ((x << n) | (x >> (8 - n))) & 0xFF


def sbox_f(a):
    b = ginv(a)
    return b ^ rotl8(b, 1) ^ rotl8(b, 2) ^ rotl8(b, 3) ^ rotl8(b, 4) ^ 0x63


SBOX = [sbox_f(i) for i in range(256)]
INV = [0] * 256
for _i, _v in enumerate(SBOX):
    INV[_v] = _i
assert SBOX[0] == 0x63 and SBOX[0x53] == 0xED


def to_b(x):
    return [(x >> (120 - 8 * n)) & 0xFF for n in range(16)]


def from_b(b):
    x = 0
    for v in b:
        x = (x << 8) | v
    return x


def sub(b):
    return [SBOX[v] for v in b]


def isub(b):
    return [INV[v] for v in b]


def shift(b):  # new s[r][c] = s[r][(c+r)%4]
    o = [0] * 16
    for c in range(4):
        for r in range(4):
            o[4 * c + r] = b[4 * ((c + r) % 4) + r]
    return o


def ishift(b):
    o = [0] * 16
    for c in range(4):
        for r in range(4):
            o[4 * ((c + r) % 4) + r] = b[4 * c + r]
    return o


def mix(b):
    o = []
    for c in range(4):
        a = b[4 * c:4 * c + 4]
        o += [gmul(a[0], 2) ^ gmul(a[1], 3) ^ a[2] ^ a[3],
              a[0] ^ gmul(a[1], 2) ^ gmul(a[2], 3) ^ a[3],
              a[0] ^ a[1] ^ gmul(a[2], 2) ^ gmul(a[3], 3),
              gmul(a[0], 3) ^ a[1] ^ a[2] ^ gmul(a[3], 2)]
    return o


def imix(b):
    o = []
    for c in range(4):
        a = b[4 * c:4 * c + 4]
        o += [gmul(a[0], 14) ^ gmul(a[1], 11) ^ gmul(a[2], 13) ^ gmul(a[3], 9),
              gmul(a[0], 9) ^ gmul(a[1], 14) ^ gmul(a[2], 11) ^ gmul(a[3], 13),
              gmul(a[0], 13) ^ gmul(a[1], 9) ^ gmul(a[2], 14) ^ gmul(a[3], 11),
              gmul(a[0], 11) ^ gmul(a[1], 13) ^ gmul(a[2], 9) ^ gmul(a[3], 14)]
    return o


def xor(a, b):
    return [x ^ y for x, y in zip(a, b)]


def key_expand(key):
    w = [to_b(key)[4 * i:4 * i + 4] for i in range(4)]
    rc = 1
    for i in range(4, 44):
        t = list(w[i - 1])
        if i % 4 == 0:
            t = sub(t[1:] + t[:1])
            t[0] ^= rc
            rc = xtime(rc)
        w.append(xor(w[i - 4], t))
    return [from_b(sum(w[4 * r:4 * r + 4], [])) for r in range(11)]


def encrypt_trace(pt, key):
    rk = key_expand(key)
    st = to_b(pt ^ rk[0])
    rounds = []
    for r in range(1, 11):
        start = st
        a = sub(st)
        b = shift(a)
        c = mix(b) if r < 10 else b
        st = xor(c, to_b(rk[r]))
        rounds.append(dict(r=r, start=from_b(start), sb=from_b(a), sr=from_b(b),
                           mc=from_b(c), rk=rk[r], out=from_b(st)))
    return rk, rounds, from_b(st)


def decrypt_trace(ct, key):
    rk = key_expand(key)
    st = to_b(ct ^ rk[10])
    rounds = []
    for r in range(9, -1, -1):
        start = st
        a = ishift(st)
        b = isub(a)
        c = xor(b, to_b(rk[r]))
        st = imix(c) if r > 0 else c
        rounds.append(dict(r=r, start=from_b(start), isr=from_b(a), isb=from_b(b),
                           ark=from_b(c), out=from_b(st)))
    return rounds, from_b(st)


def aes_ecb(pt, key):
    return encrypt_trace(pt, key)[2]


def table_case(t):
    return "".join(f"      8'h{i:02x}: o_byte = 8'h{t[i]:02x};\n" for i in range(256))


SBOX_HDR = """// -----------------------------------------------------------------------------
// {name} : {desc}. Puramente combinacional.
// Tabela gerada por scripts/gen_aes_ref.py (inversa em GF(2^8) + transformacao afim).
// -----------------------------------------------------------------------------
module {name} (
  input  logic [7:0] i_byte,
  output logic [7:0] o_byte
);
  always_comb begin
    unique case (i_byte)
{body}    endcase
  end
endmodule
"""

if __name__ == "__main__":
    KB = 0x2b7e151628aed2a6abf7158809cf4f3c
    PB = 0x3243f6a8885a308d313198a2e0370734
    CB = 0x3925841d02dc09fbdc118597196a0b32
    KC = 0x000102030405060708090a0b0c0d0e0f
    PC = 0x00112233445566778899aabbccddeeff
    CC = 0x69c4e0d86a7b0430d8cdb78070b4c55a

    rkB, rB, outB = encrypt_trace(PB, KB)
    assert outB == CB
    rkC, rC, outC = encrypt_trace(PC, KC)
    assert outC == CC
    dB, ptB = decrypt_trace(CB, KB)
    assert ptB == PB
    dC, ptC = decrypt_trace(CC, KC)
    assert ptC == PC
    assert rB[0]["start"] == 0x193de3bea0f4e22b9ac68d2ae9f84808
    assert rB[0]["sb"] == 0xd42711aee0bf98f1b8b45de51e415230
    assert rB[0]["sr"] == 0xd4bf5d30e0b452aeb84111f11e2798e5
    assert rkC[10] == 0x13111d7fe3944a17f307a78b4d2b30c5
    try:
        from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
        random.seed(2026)
        for _ in range(200):
            k, p = random.getrandbits(128), random.getrandbits(128)
            e = Cipher(algorithms.AES(k.to_bytes(16, 'big')), modes.ECB()).encryptor()
            assert int.from_bytes(e.update(p.to_bytes(16, 'big')), 'big') == aes_ecb(p, k)
        print("modelo == biblioteca 'cryptography' em 200 vetores aleatorios")
    except ImportError:
        pass
    print("modelo Python confere com FIPS-197 (Apendices B e C.1)")

    with open(f"{ROOT}/rtl/minisoc_aes/minisoc_aes_sbox.sv", "w") as f:
        f.write(SBOX_HDR.format(name="minisoc_aes_sbox",
                                desc="S-box AES (FIPS-197, Figura 7)",
                                body=table_case(SBOX)))
    with open(f"{ROOT}/rtl/minisoc_aes/minisoc_aes_inv_sbox.sv", "w") as f:
        f.write(SBOX_HDR.format(name="minisoc_aes_inv_sbox",
                                desc="S-box inversa AES (FIPS-197, Figura 14)",
                                body=table_case(INV)))

    L = ["// Gerado por scripts/gen_aes_ref.py - NAO EDITAR"]

    def arr(name, vals, w=128):
        body = ",\n  ".join(f"{w}'h{v:0{w // 4}x}" for v in vals)
        L.append(f"localparam logic [{w - 1}:0] {name} [0:{len(vals) - 1}] = '{{\n  {body}\n}};")

    for tag, rr, dd, key in (("B", rB, dB, KB), ("C", rC, dC, KC)):
        arr(f"APP{tag}_RK", key_expand(key))
        arr(f"APP{tag}_E_START", [x["start"] for x in rr])
        arr(f"APP{tag}_E_SB", [x["sb"] for x in rr])
        arr(f"APP{tag}_E_SR", [x["sr"] for x in rr])
        arr(f"APP{tag}_E_MC", [x["mc"] for x in rr])
        arr(f"APP{tag}_E_OUT", [x["out"] for x in rr])
        arr(f"APP{tag}_D_START", [x["start"] for x in dd])
        arr(f"APP{tag}_D_ISR", [x["isr"] for x in dd])
        arr(f"APP{tag}_D_ISB", [x["isb"] for x in dd])
        arr(f"APP{tag}_D_ARK", [x["ark"] for x in dd])
        arr(f"APP{tag}_D_OUT", [x["out"] for x in dd])

    random.seed(1234)
    N = 64
    ks = [random.getrandbits(128) for _ in range(N)]
    ps = [random.getrandbits(128) for _ in range(N)]
    cs = [aes_ecb(p, k) for p, k in zip(ps, ks)]
    arr("RND_KEY", ks)
    arr("RND_PT", ps)
    arr("RND_CT", cs)
    L.append(f"localparam int N_RND = {N};")
    mc = [random.getrandbits(128) for _ in range(32)]
    arr("MC_IN", mc)
    arr("MC_OUT", [from_b(mix(to_b(x))) for x in mc])
    arr("IMC_OUT", [from_b(imix(to_b(x))) for x in mc])
    L.append("localparam int N_MC = 32;")
    with open(f"{ROOT}/tb/vectors/aes_vectors.svh", "w") as f:
        f.write("\n".join(L) + "\n")
    print("RTL das S-boxes e tb/vectors/aes_vectors.svh gerados")
