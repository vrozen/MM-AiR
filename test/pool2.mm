/*
  This test demonstrates maximum pool values.
*/

source tick
auto pool count
tick --> count
assert ends : count < 20 "ok"

pool A at 20
auto pool B max 1
auto pool C max 5
auto pool D
A --> B
B --> C
B --> D

assert sane : B <= 1 "pools can specify a miximum"

assert sane : C <= 5 "pools can specify a maximum"

assert sane : A + B + C + D == 20 "maximum values do not cause resource generation or consumption"