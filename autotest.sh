

touch autotest_result.txt    # Use this to record all cases' result
touch make_messages.txt      # Use this to prevent printing make messages to the command line, so that we can see the results easily
rm -rf testout
mkdir testout
make clean > make_messages.txt 
make simv                         # than generate our output

# for file in test_progs/*.s; do

#     file=$(echo $file | cut -d'.' -f1)

#     echo "Testing $file" 
#     make assembly SOURCE=$file.s > make_messages.txt       # First produce the program.mem
#     ./simv > program.out


#     file=$(echo $file | cut -d'/' -f2)

#     cp program.out testout/$file.out

#     cat program.out | grep "^@@@[^\n]*" > new_program.out
#     diff new_program.out std_output/$file.program.out > program.diff.out
#     if [ $? == 0 ]; then
#         echo -e "\033[32mTestcase $file program passed!\033[0m"
#         echo "Testcase $file program passed" >> autotest_result.txt
#     else
#         echo -e "\033[31mTestcase $file program failed!\033[0m"
#         echo "Testcase $file program failed" >> autotest_result.txt
#     fi
#     rm *.out

# done

# for file in test_progs/*.c; do                                       # Similar procedure for c files
    # file=$(echo $file | cut -d'.' -f1)
    file=test_progs/quicksort
    echo "Testing $file" 
    make program SOURCE=$file.c > make_messages.txt
    ./simv > program.out

    file=$(echo $file | cut -d'/' -f2)

    cp program.out testout/$file.out

    cat program.out | grep "^@@@[^\n]*" > new_program.out
    diff new_program.out std_output/$file.program.out > program.diff.out
    if [ $? == 0 ]; then
        echo -e "\033[32mTestcase $file program passed!\033[0m"
        echo "Testcase $file program passed" >> autotest_result.txt
    else
        echo -e "\033[31mTestcase $file program failed!\033[0m"
        echo "Testcase $file program failed" >> autotest_result.txt
    fi

    rm *.out

# done

rm make_messages.txt
make clean

