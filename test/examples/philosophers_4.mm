//four dining philosophers
pool fork1 at 1
pool spoon1 at 1
pool fork2 at 1
pool spoon2 at 1

Philosopher hans    fork1 .=.> hans.fork    spoon1 .=.> hans.spoon
Philosopher jan     fork2 .=.> jan.fork     spoon1 .=.> jan.spoon
Philosopher ludwig  fork2 .=.> ludwig.fork  spoon2 .=.> ludwig.spoon
Philosopher karl    fork1 .=.> karl.fork    spoon2 .=.> karl.spoon

Philosopher(ref fork, ref spoon)
{
  auto pool hasFork
  auto pool hasSpoon
  auto all converter eat

  fork --> hasFork
  spoon --> hasSpoon
  hasFork --> eat
  hasSpoon --> eat
  eat --> fork
  eat --> spoon
  
  assert eats : (hasFork == 0 && hasSpoon == 0) ||
                (hasFork == 1 && hasSpoon == 1)
                "philosophers either eat or not"
}