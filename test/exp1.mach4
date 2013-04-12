/*
  This test demonstrates arithmetic and boolean expressions.
  Note: A contextual analyzer (a.k.a. checker) for malformed expressions is still missing.
*/

pool A at 2
pool B at 2 add A / 2 + 1

assert ends : false  "ok" //end immediately

assert sane : ! false   "boolean not"
assert sane : 4 != 5    "boolean not equals"
assert sane : 5 > 4     "boolean greater than"
assert sane : !(4 > 4)  "boolean greater than"
assert sane : 4 >= 4    "boolean greater equals"
assert sane : !(3>=4)   "boolean greater equals"
assert sane : 3 < 4     "boolean less than"
assert sane : !(4 < 3)  "boolean less than"
assert sane : 3 <= 3    "boolean less equals"
assert sane : !(4 <= 3) "boolean less equals"

assert sane : false || true    "boolean or"
assert sane : A == 4 || B == 4 "boolean or"
assert sane : A == 2 && B == 4 "boolean and"
assert sane : ! (A == 2 && B == 2) "boolean and"

assert sane : 4 != 5      "arithemtic not equals"
assert sane : A == 2      "arithmetic name reference"

assert sane : 2 + 3 == 5  "arithmetic addition"
assert sane : 4 - 3 == 1  "arithmetic subtraction"
assert sane : ~3 + 4 == 1 "arithmetic unary minus"
assert sane : ~1 -~3 == 2 "arithmetic unary minus"
assert sane : B == 4 "pool addition expressions"

//assert true != 4   "bool / arith not equals"
