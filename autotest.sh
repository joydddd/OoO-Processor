

touch autotest_result.txt    # Use this to record all cases' result
touch make_messages.txt      # Use this to prevent printing make messages to the command line, so that we can see the results easily
make clean > make_messages.txt 

for file in test_progs/*.s; do

    file=$(echo $file | cut -d'.' -f1)

    echo "Testing $file" 
    make assembly SOURCE=$file.s > make_messages.txt       # First produce the program.mem
    make > make_messages.txt                               # than generate our output


    file=$(echo $file | cut -d'/' -f2)
    diff writeback.out std_output/$file.writeback.out > write.diff.out      # Compare out output with the standard output
    if [ $? == 0 ]; then
        echo -e "\033[32mTestcase $file writeback passed!\033[0m"          # Use green color for correct output
        echo "Testcase $file writeback passed" >> autotest_result.txt
    else
        echo -e "\033[31mTestcase $file writeback failed!\033[0m"
        echo "Testcase $file writeback failed" >> autotest_result.txt       # Use red color for correct output
    fi

    cat program.out | grep "^@@@[^\n]*" > new_program.out
    diff new_program.out std_output/$file.program.out > program.diff.out
    if [ $? == 0 ]; then
        echo -e "\033[32mTestcase $file program passed!\033[0m"
        echo "Testcase $file program passed" >> autotest_result.txt
    else
        echo -e "\033[31mTestcase $file program failed!\033[0m"
        echo "Testcase $file program failed" >> autotest_result.txt
    fi

    make clean > make_messages.txt

done

for file in test_progs/*.c; do                                       # Similar procedure for c files
 
    file=$(echo $file | cut -d'.' -f1)

    echo "Testing $file" 
    make program SOURCE=$file.c > make_messages.txt
    make > make_messages.txt


    file=$(echo $file | cut -d'/' -f2)
    diff writeback.out std_output/$file.writeback.out > write.diff.out
    if [ $? == 0 ]; then
        echo -e "\033[32mTestcase $file writeback passed!\033[0m"
        echo "Testcase $file writeback passed" >> autotest_result.txt
    else
        echo -e "\033[31mTestcase $file writeback failed!\033[0m"
        echo "Testcase $file writeback failed" >> autotest_result.txt
    fi

    cat program.out | grep "^@@@[^\n]*" > new_program.out
    diff new_program.out std_output/$file.program.out > program.diff.out
    if [ $? == 0 ]; then
        echo -e "\033[32mTestcase $file program passed!\033[0m"
        echo "Testcase $file program passed" >> autotest_result.txt
    else
        echo -e "\033[31mTestcase $file program failed!\033[0m"
        echo "Testcase $file program failed" >> autotest_result.txt
    fi

    make clean > make_messages.txt

done

rm make_messages.txt

