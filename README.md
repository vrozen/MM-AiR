MM-AiR
======

Micro-Machinations is a reengineered subset of Machinations intended for analysis and transformation.

Getting Started.

1. Import the project in 2nd level Eclipse.
2. Plugin.rsc should automaticall register the machinations language with extension .mach4 to Eclipse.
   * As an alternative to step 2 type the following in the Rascal console: ```import lang::machinations::Machinations; registerMachinations();```
3. To run the regression / sanity tests type the following in the Rascal console: ```import lang::machinations::RegTest; testAll();```

Usage.

1. Create a file with suffix .mach for to create a new intermediate model.
  * See ```/src/lang/machinations/test``` for examples
  * See ```/src/lang/machinations/Syntax.rsc``` for the syntax.
2. To visualize richt click in the code, click Machinations, click visualize.
  * This will open the visualization which shows graphical Machinations and supports interactive simulation.
