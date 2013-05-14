/*
  This test demonstrates flows that happen once every so many steps.
*/

source tick
auto pool count
tick --> count

source units
pool defence
units -3|4-> defence

assert ends : count < 16 "ok"

assert sane : count == 0 && defence == 0 ||
              count == 1 && defence == 0 ||
              count == 2 && defence == 0 ||
              count == 3 && defence == 0 ||
              count == 4 && defence == 3 ||
              count == 5 && defence == 3 ||
              count == 6 && defence == 3 ||
              count == 7 && defence == 3 ||
              count == 8 && defence == 6 ||
              count == 9 && defence == 6 ||
              count == 10 && defence == 6 ||
              count == 11 && defence == 6 ||
              count == 12 && defence == 9 ||
              count == 13 && defence == 9 ||
              count == 14 && defence == 9 ||
              count == 15 && defence == 9 ||
              count > 15
              "3 flow from units to defence every 4 turns"