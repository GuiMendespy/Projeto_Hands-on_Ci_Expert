# Gera sbox/inv_sbox (via inversa em GF(2^8) + afim) e vetores de rodada do Apêndice B
def xt(a): 
    a<<=1
    return (a^0x11b)&0xff if a&0x100 else a
def gm(a,b):
    r=0
    while b:
        if b&1: r^=a
        a=xt(a); b>>=1
    return r
def rotl(x,n): return ((x<<n)|(x>>(8-n)))&0xff
S=[]
for x in range(256):
    inv=0
    if x:
        inv=next(y for y in range(1,256) if gm(x,y)==1)
    S.append(inv^rotl(inv,1)^rotl(inv,2)^rotl(inv,3)^rotl(inv,4)^0x63)
assert S[0]==0x63 and S[0x53]==0xed
IS=[0]*256
for i,v in enumerate(S): IS[v]=i

def table(name,T):
    return "".join(f"      8'h{i:02x}: {name} = 8'h{T[i]:02x};\n" for i in range(256))
open("rtl/minisoc_aes_sbox.sv","w").write(f"""// S-box AES (FIPS-197, Figura 7). Puramente combinacional.
module minisoc_aes_sbox (
    input  logic [7:0] i_byte,
    output logic [7:0] o_byte
);
  always_comb begin
    case (i_byte)
{table('o_byte',S)}    endcase
  end
endmodule
""")
open("rtl/minisoc_aes_inv_sbox.sv","w").write(f"""// InvS-box AES (FIPS-197, Figura 14). Puramente combinacional. (opcional)
module minisoc_aes_inv_sbox (
    input  logic [7:0] i_byte,
    output logic [7:0] o_byte
);
  always_comb begin
    case (i_byte)
{table('o_byte',IS)}    endcase
  end
endmodule
""")

# Vetores: AES-128 do Apêndice B
key=bytes.fromhex("2b7e151628aed2a6abf7158809cf4f3c")
pt=bytes.fromhex("3243f6a8885a308d313198a2e0370734")
rc=[1,2,4,8,0x10,0x20,0x40,0x80,0x1b,0x36]
w=[list(key[4*i:4*i+4]) for i in range(4)]
for i in range(4,44):
    t=w[i-1][:]
    if i%4==0:
        t=t[1:]+t[:1]; t=[S[b] for b in t]; t[0]^=rc[i//4-1]
    w.append([a^b for a,b in zip(w[i-4],t)])
rk=[sum(w[4*r:4*r+4],[]) for r in range(11)]
def sb(s): return [S[b] for b in s]
def sr(s): return [s[(n%4)+4*(((n//4)+(n%4))%4)] for n in range(16)]
def mc(s):
    o=[]
    for c in range(4):
        a=s[4*c:4*c+4]
        o+= [gm(2,a[0])^gm(3,a[1])^a[2]^a[3], a[0]^gm(2,a[1])^gm(3,a[2])^a[3],
             a[0]^a[1]^gm(2,a[2])^gm(3,a[3]), gm(3,a[0])^a[1]^a[2]^gm(2,a[3])]
    return o
ark=lambda s,k:[a^b for a,b in zip(s,k)]
st=ark(list(pt),rk[0]); rows=[]
for r in range(1,11):
    a=sb(st); b=sr(a); rows.append((st,a,b))
    st=ark(b if r==10 else mc(b),rk[r])
assert bytes(st).hex()=="3925841d02dc09fbdc118597196a0b32", bytes(st).hex()
assert bytes(rows[0][0]).hex()=="193de3bea0f4e22b9ac68d2ae9f84808"
assert bytes(rows[0][2]).hex()=="d4bf5d30e0b452aeb84111f11e2798e5"
h=lambda s:"128'h"+bytes(s).hex()
with open("tb/aes_vectors.svh","w") as f:
    f.write("// Gerado por gen.py a partir de AES-128 (FIPS-197 Apendice B); cifra final conferida = 3925841d...0b32\n")
    for i,(s,a,b) in enumerate(rows):
        f.write(f"    v_start[{i}] = {h(s)}; v_sub[{i}] = {h(a)}; v_sh[{i}] = {h(b)};\n")
print("ok; round10:",[bytes(x).hex() for x in rows[9]])
