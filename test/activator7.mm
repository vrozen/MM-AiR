source tick
auto pool count
tick --> count

auto drain pickOne
auto drain pickTwo
tick --> pickOne
tick --> pickTwo

count .count<=3 || count > 5.> pickOne
count .count>3 && count <= 5.>  pickTwo

pickOne .*.> one
pickTwo .*.> two

pool one
pool two

tick --> one
tick --> two

assert ends : count < 10 "ok"

