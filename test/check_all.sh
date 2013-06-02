rm *.svr
rm *.tmp
rm *.mmt
rm *.trail
rm pan.*
for file in `ls *.pml`;
do
  echo -----------------------------------------------------------------------------
  echo CheckAll: Checking $file
  echo -----------------------------------------------------------------------------
  echo CheckAll: 1. Generate verifier in pan.c
  rm pan.*
  spin -a $file
  echo CheckAll: 2. Compile pan.c to verifier binary `basename $file .pml`
  rm `basename $file .pml` 
  gcc pan.c -DSAFETY -DREACH -o `basename $file .pml`
  rm pan.*
  chmod 700 `basename $file .pml`
  echo CheckAll: 3. Run verifier for maximum 1 minute
  ./`basename $file .pml` -i >> `basename $file .pml`.svr
  echo CheckAll: 4. Generated `basename $file .pml`.svr and $file.trail
  echo CheckAll: 5. Play back $file.trail on verifier.
  ./`basename $file .pml` -r -S >> `basename $file .pml`.tmp
  grep ^MM `basename $file .pml`.tmp >> `basename $file .pml`.mmt
  rm `basename $file .pml`.tmp
  echo CheckAll: 6. Output stored in `basename $file .pml`.mmt
done
