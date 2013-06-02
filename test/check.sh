rm `basename $1 .pml`.svr
rm `basename $1 .pml`.tmp
rm `basename $1 .pml`.mmt
rm $1.trail
rm pan.*
echo -----------------------------------------------------------------------------
echo Check: Checking $1
echo -----------------------------------------------------------------------------
echo Check: 1. Generate verifier in pan.c
spin -a $1
echo Check: 2. Compile pan.c to verifier binary `basename $1 .pml`
rm `basename $1 .pml`
gcc pan.c -DSAFETY -DREACH -o `basename $1 .pml`
rm pan.*
chmod 700 `basename $1 .pml`
echo Check: 3. Run verifier
./`basename $1 .pml` -I -m20000 >> `basename $1 .pml`.svr
echo Check: 4. Generated `basename $1 .pml`.svr and $1.trail
echo Check: 5. Play back $1.trail on verifier.
./`basename $1 .pml` -r -S $1.trail >> `basename $1 .pml`.tmp
grep ^MM `basename $1 .pml`.tmp >> `basename $1 .pml`.mmt
echo CheckAll: 6. Output stored in `basename $1 .pml`.mmt
