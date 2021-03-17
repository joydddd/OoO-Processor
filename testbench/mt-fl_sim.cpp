/////////////////////////////////////
/// simulation of a maptable
////////////////////////////////////
#define PR_SIZE 64
#define AR_SIZE 32
#include "mt-fl_sim.h"

#include <deque>
#include <iostream>
#include <vector>
using std::cerr;
using std::deque;
using std::endl;
using std::vector;

/* free list simulation */
static deque<int> freelist;

extern "C" void fl_init() {
    for (int i = AR_SIZE; i < PR_SIZE; i++) {
        freelist.push_back(i);
    }
}

extern "C" int fl_new_pr_valid() {
    if (freelist.size() >= 3)
        return 0x0;  // 3'b000;
    else if (freelist.size() == 2)
        return 0x1;  // 3'b001;
    else if (freelist.size() == 1)
        return 0x3;  // 3'b011;
    else if (freelist.size() == 0)
        return 0x7;  // 3'b111;
    return 0x7;
}

extern "C" int fl_new_pr2() {
    if (freelist.size() < 1)
        return 0;
    else
        return freelist[0];
}

extern "C" int fl_new_pr1() {
    if (freelist.size() < 2)
        return 0;
    else
        return freelist[1]
}

extern "C" int fl_new_pr0() {
    if (freelist.size() < 3)
        return 0;
    else
        return freelist[2];
}

extern "C" int fl_pop(int new_pr_en) {
    if (new_pr_en == 0x0) {
        assert(freelist.size() >= 3) freelist.pop();
        freelist.pop();
        freelist.pop();
    } else if (new_pr_en == 0x1) {
        assert(freelist.size() >= 2);
        freelist.pop();
        freelist.pop();
    } else if (new_pr_en == 0x3) {
        assert(freelist.size() >= 1);
        freelist.pop();
    } else if (new_pr_en == 0x7) {
        ;
    } else {
        cerr << "Invalid new_pr_en signal: " << new_pr_en;
        assert(false);
    }
}

/* map table simulation */
static vector<int> mapTable;

extern "C" void mt_init() {
    for (int i = 0; i < AR_SIZE; i++) {
        mapTable.push_back(i);
    }
}

extern "C" int look_up(int i) {
    assert(i <= AR_SIZE);
    return mapTable[i];
}

extern "C" int map(int ar, int pr) {
    if (ar == 0 && pr != 0) {
        cerr << "ERROR: maping AR 0 to PR " << pr << endl;
    }
    if (pr == 0 && ar != 0) {
        cerr << "ERROR: mapping AR " << ar << " to PR 0" << endl;
    }
    mapTable[ar] = pr;
}