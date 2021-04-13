///////////////////////////////////
/////        print memory
//////////////////////////////////
#include <stdint.h>

#include <fstream>
#include <iostream>
#include <vector>

using namespace std;

/* memory */
static vector<uint8_t> memory_final(64*1024);

extern "C" void mem_copy(int addr_int, int data_int) {
    uint32_t addr = (uint32_t)addr_int;
    uint32_t data = (uint32_t)data_int;
    memory_final[addr+3] = (data >> 24) % 256;
    memory_final[addr+2] = (data >> 16) % 256;
    memory_final[addr+1] = (data >>  8) % 256;
    memory_final[addr+0] = data % 256;
}

extern "C" void mem_final_print() {
    printf("@@@\n");
	int showing_data=0;
	for(int k=0;k<=8192; k=k+1)
		if (memory_final[k*8] != 0 || memory_final[k*8+1] != 0 || memory_final[k*8+2] != 0 || memory_final[k*8+3] != 0 ||
            memory_final[k*8+4] != 0 || memory_final[k*8+5] != 0 || memory_final[k*8+6] != 0 || memory_final[k*8+7] != 0){
            uint64_t mem_temp = (memory_final[k*8+7] << 56) + (memory_final[k*8+6] << 48) + (memory_final[k*8+5] << 40) + (memory_final[k*8+4] << 32) +
			                    (memory_final[k*8+3] << 24) + (memory_final[k*8+2] << 16) + (memory_final[k*8+1] << 8) + memory_final[k*8];
			cout << mem_temp << endl;
            printf("@@@ mem[%5d] = %016x : %0d\n", k*8, mem_temp, mem_temp);
			showing_data=1;
        } else if(showing_data!=0) {
			printf("@@@\n");
			showing_data=0;
        }
	printf("@@@\n");
}