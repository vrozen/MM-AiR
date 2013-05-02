//two dining philosophers
pool fork at 1
pool spoon at 1
Philosopher hans  fork .=.> hans.fork  spoon .=.> hans.spoon
Philosopher jan   fork .=.> jan.fork   spoon .=.> jan.spoon

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