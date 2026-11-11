// Funcoes de aritmetica em GF(2^8), polinomio irredutivel x^8+x^4+x^3+x+1.
package minisoc_aes_gf_pkg;
  function automatic logic [7:0] xtime(input logic [7:0] a);
    return {a[6:0], 1'b0} ^ (a[7] ? 8'h1b : 8'h00);
  endfunction

  function automatic logic [7:0] mul2(input logic [7:0] a);  return xtime(a); endfunction
  function automatic logic [7:0] mul3(input logic [7:0] a);  return xtime(a) ^ a; endfunction
  function automatic logic [7:0] mul9(input logic [7:0] a);
    return xtime(xtime(xtime(a))) ^ a;
  endfunction
  function automatic logic [7:0] mul11(input logic [7:0] a);
    return xtime(xtime(xtime(a))) ^ xtime(a) ^ a;
  endfunction
  function automatic logic [7:0] mul13(input logic [7:0] a);
    return xtime(xtime(xtime(a))) ^ xtime(xtime(a)) ^ a;
  endfunction
  function automatic logic [7:0] mul14(input logic [7:0] a);
    return xtime(xtime(xtime(a))) ^ xtime(xtime(a)) ^ xtime(a);
  endfunction
endpackage
