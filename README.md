## Usage:
- make assembly            <- translate the .s program into hex and store in program.mem
- make program             <- translate the .c program into hex and store in program.mem
- make simv                <- create an executable named simv
- make syn_simv            <- run synthesis and create an executable named syn_simv
- ./simv > program.out     <- run the simulation executable and direct the output to program.out
- ./syn_simv > program.out <- run the synthesized executable and direct the output to program.out

## Something important:
- Running "make syn_simv" on our project takes about 2 hours to finish
- The largest number of cycles given for a single program to run is 5,000,000. It's defined at the top of testbench_fin.sv (`define MAX_CYCLE 5000000)
- These public test programs take more than 300 seconds to complete by simulation: 
    - outer_product.c (320s)
- These public test programs take more than 300 seconds to complete by synthesis: 



## Passed tests: 
- haha.s
- mult_no_lsq.s
- rv32_btest1.s
- rv32_btest2.s
- rv32_copy.s
- rv32_evens.s
- rv32_evens_long.s
- rv32_halt.s
- rv32_parallel.s
- rv32_copy_long.s
- rv32_fib.s
- rv32_fib_long.s
- rv32_fib_rec.s
- rv32_insertion.s
- rv32_mult.s
- rv32_saxpy.s
- sampler.s
- backtrack.c
- basic_malloc.c
- bfs.c
- fc_forward.c
- graph.c
- insertionsort.c
- mergesort.c
- omegalul.c
- priority_queue.c
- alexnet.c
- dft.c
- matrix_mult_rec.c
- outer_product.c

## Unpassed tests (wrong results):
- quicksort.c

