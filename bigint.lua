-- bigint

function divmod(x,d)
 return x\d, x%d
end

function xor(a,b)
 return (a or b) and not (a and b)
end

bigint = {}
bigint._meta = {}

function bigint._rem_0s(b)
 local i = #b.coef
 while i > 0 and b.coef[i] == 0 do
  b.coef[i] = nil
  i -= 1
 end
end

function bigint._tokenise(s)
 -- extract sign
 local sign = true
 if sub(s,1,1) == "-" then
  s = sub(s,2)
  sign = false
 end

 -- strip leading 0s
 s = str_lstrip(s,"0")
 sign = sign or #s == 0

 -- strip , and terminate on .
 local ns = ""
 for i=1,#s do
  local c = sub(s,i,i)
  if c == "." then break
  elseif c~="," then
   ns ..= c
  end
 end
 -- validate characters
 for i=1,#ns do
  assert(str_in(sub(ns,i,i),"1234567890"))
 end
 -- group every 2 digits
 -- from right to left
 ns = str_divvy(str_reverse(ns), 2)
 return sign,lmap(str_reverse,ns)
end

function bigint._add(b1,b2)
 if #b1.coef < #b2.coef then
  b1,b2 = b2, b1
 end

 b1 = bigint.copy(b1)

 local carry,c1,c2 = 0, b1.coef, b2.coef
 for i=1,#c1 do
  carry, c1[i] =
    divmod(c1[i]+c2[i]+carry,
           100)
  if carry == 0 and i >= #c2 then
   break
  end
 end
 if carry ~= 0 then
  c1[#c1+1] += carry
 end
 return b1
end

function bigint._sub(b1, b2)
 if b1 < b2 then
  return -bigint._sub(b2,b1)
 end
 b1 = bigint.copy(b1)

 local carry,c1,c2 = 0, b1.coef, b2.coef
 for i=1,#c1 do
  carry, c1[i] =
    divmod(c1[i]-c2[i]+carry,
           100)
  if carry == 0 and i >= #c2 then
   break
  end
 end
 if carry ~= 0 then
  c1[#c2+1] += carry
 end
 -- remove leading 0s
 bigint._rem_0s(b1)
 return b1
end

function bigint._meta.__add(b1,b2)
 b1 = bigint.as_bigint(b1)
 b2 = bigint.as_bigint(b2)
 if b1.sign and not b2.sign then
  return b1-(-b2)
 elseif b2.sign and not b1.sign then
  return b2-(-b1)
 end
 return bigint._add(b1,b2)
end

function bigint._meta.__sub(b1, b2)
 b1 = bigint.as_bigint(b1)
 b2 = bigint.as_bigint(b2)
 if b1.sign and not b2.sign then
  return b1+(-b2)
 elseif b2.sign and not b1.sign then
  return -((-b1)+b2)
 end
 return bigint._sub(b1,b2)
end

-- better algorithms exist but
-- i simply do not know them
function bigint._meta.__mul(b1,b2)
 b2 = bigint.as_bigint(b2)
 b1 = bigint.copy(b1)
 b1.sign = not xor(b1.sign,b2.sign)

 local c1, c2 = b1.coef, b2.coef
 local l1,l2=#c1,#c2
 local lt = l1+l2
 local x, carry

 local buckets={}
 for i=1,lt do
  add(buckets,{})
 end

 for i=1,l1 do
  for j=1,l2 do
   carry,x = divmod(c1[i] * c2[j],100)
   add(buckets[i+j-1],x)
   add(buckets[i+j],carry)
  end
 end
 for i=1,lt do
  -- for very large numbers
  -- the lack of divmod per
  -- sum might cause overflow
  x=0
  for v in all(buckets[i]) do
   x+=v
  end
  carry, c1[i] = divmod(x,100)
  add(buckets[i+1],carry)
 end
 bigint._rem_0s(b1)
 return b1
end

function bigint._meta.__pow(b,n)
 acc = bigint.copy(b)
 for i=2,n do
  acc *= b
 end
 return acc
end

function bigint._meta.__unm(b)
 if #b.coef == 0 then
  return b
 end
 b = bigint.copy(b)
 b.sign = not b.sign
 return b
end

function bigint._meta.__eq(b1,b2)
 return not (b1 < b2 or b2 < b1)
 --if #b1.coef ~= #b2.coef or b1.sign ~= b2.sign then
 -- return false
 --end
 --for i=1,#b1.coef do
 -- if b1.coef[i] ~= b2.coef[i] then
 --  return false
 -- end
 --end
 --return true
end

function bigint._meta.__lt(b1,b2)
 b1 = bigint.as_bigint(b1)
 b2 = bigint.as_bigint(b2)
 if b1.sign != b2.sign then
  return not b1.sign and b2.sign
 end
 local c1, c2 = b1.coef, b2.coef
 if #c1 != #c2 then
  return not xor(b1.sign,
                 #c1 < #c2)
 end
 for i=#c1,1,-1 do
  if c1[i] != c2[i] then
   return
     not xor(b1.sign,
             c1[i]<c2[i])
  end
 end
 return false
end

function bigint._meta.__concat(x,y)
 return tostr(x)..tostr(y)
end

function bigint._meta.__tostring(b)
 if #b.coef == 0 then
  return "0"
 end
 local start = #b.coef
 local s = ""
 -- build string from components
 for i=start,1,-1 do
  local ss = tostr(b.coef[i])
  if #ss ~= 2 then
   s ..= "0"
  end
  s ..= ss
 end
 -- remove leading 0s
 s = str_lstrip(s,"0")
 -- add commas
 local ns = sub(s,-1,-1)
 for i=2,#s do
  if i % 3 == 1 then
   ns ..= ","
  end
  ns ..= sub(s,-i,-i)
 end
 -- add negative
 if not b.sign then
  ns..="-"
 end
 return str_reverse(ns)
end

function bigint._new()
 local b = {coef={}, sign=true}
 setmetatable(b, bigint._meta)
 setmetatable(b.coef,{
  __index=function()return 0end})
 return b
end

function bigint.new(s)
 if type(s) == "number" then
  s = tostr(s)
 end
 assert(#s > 0)

 local ts
 local b = bigint._new()
 b.sign, ts = bigint._tokenise(s)
 for i=1,#ts do
  add(b.coef, tonum(ts[i]))
 end
 return b
end

-- can replace with generic deepcopy
function bigint.copy(b)
 if type(v) == "number" or
    type(v) == "string" then
  return bigint.new(b)
 end
 local nb = bigint._new()
 nb.sign = b.sign
 for i=1,#b.coef do
  nb.coef[i]=b.coef[i]
 end
 return nb
end

function bigint.as_bigint(v)
 if type(v) == "number" or
    type(v) == "string" then
  return bigint.new(v)
 end
 return v
end
-->8
-- string utils

function str_in(ss, s)
 for i=1,#s-#ss+1 do
  if sub(s, i,i+#ss-1) == ss then
   return true
  end
 end
 return false
end

function str_reverse(s)
 local ns=""
 for i=1,#s do
  ns..=sub(s,-i,-i)
 end
 return ns
end

function str_concat(strs)
 local s=""
 for ss in all(strs) do
  s..=ss
 end
 return s
 --return lfold(
 --  function(a,b) return a..b end,
 --  strs)
end

function str_divvy(s, n)
 local subs = {}
 for i=1,#s,n do
  add(subs, sub(s,i,i+n-1))
 end
 return subs
end


function str_lstrip(s,ss)
 local start = 1
 while (start <= #s and
   str_in(sub(s,start,start), ss)) do
  start+=1
 end
 return sub(s,start)
end
-->8
-- list utils

function reverse(l)
 local result = {}
 for i=#l,1,-1 do
  add(result,l[i])
 end
 return result
end

function lmap(f,l)
 local nl={}
 for v in all(l) do
  add(nl, f(v))
 end
 return nl
end
