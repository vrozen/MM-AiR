MM-AiR
======

Micro-Machinations is a re-engineered subset of Machinations intended for analysis and transformation.

Getting Started.

1. Import the project in 2nd level Eclipse.
2. Plugin.rsc should automatically register the Micro-Machinations language with extension .mm and Micro-Machinations Trace language .mmt to Eclipse.
   * As an alternative to step 2 type the following in the Rascal console: ```import lang::machinations::Machinations; mm_register();```
3. To run the regression / sanity tests type the following in the Rascal console: ```import lang::machinations::RegTest; mm_testAllToPromela();``` Now run ```.check_all.sh``` on the command prompt (requires Spin), then refresh the project and finally ```mm_testAll();```

Usage.

1. Create a file with suffix .mm for to create a new intermediate Micro-Machinations model.
  * See ```/test``` for regression test examples that demonstrate semantics
  * See ```/test/examples``` for example models
  * See ```/src/lang/machinations/Syntax.rsc``` for the syntax.
2. To visualize richt click in the code, click Machinations, click Visualize.
  * This will open the visualization which shows graphical Machinations and supports interactive simulation.
