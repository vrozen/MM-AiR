/*
  This test demonstrates that gates must have at
  least one output that is guaranteed to be enabled.
 */
source S
auto gate G
pool A max 1
pool B max 1
S --> G
G --> A
G --> B

