rm *.spin_out
rm *.verifier_out
for file in `ls *.pml`;
do
  echo -----------------------------------------------------------------------------
  echo CheckAll: Checking $file
  echo -----------------------------------------------------------------------------
  echo CheckAll: 1. Generate verifier in pan.c
  spin -a $file
  echo CheckAll: 2. Compile pan.c to verifier binary `basename $file .pml`
  rm `basename $file .pml`
  gcc pan.c -DSAFETY -o `basename $file .pml`
  rm pan.c
  chmod 700 `basename $file .pml`
  echo CheckAll: 3. Run verifier to a depth of 1M
  ./`basename $file .pml` -u1000000 >> `basename $file .pml`.verifier_out
  echo CheckAll: 4. Generated `basename $file .pml`.verifier_out and $file.trail
  echo CheckAll: 5. Play back $file.trail on verifier.
  ./`basename $file .pml` -r -S $file.trail >> `basename $file .pml`.spin_out
  echo CheckAll: 6. Output stored in `basename $file .pml`.spin_out
done
