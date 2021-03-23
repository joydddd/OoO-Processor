/////////////////////////////////////
/// simulation of a maptable
////////////////////////////////////
#define PR_SIZE 64
#define AR_SIZE 32

#include <assert.h>

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
    cerr << "FreeList Reseted!" << endl;
}

extern "C" int fl_new_pr_valid() {
    if (freelist.size() >= 3)
        return 0x7;  // 3'b111;
    else if (freelist.size() == 2)
        return 0x3;  // 3'b011;
    else if (freelist.size() == 1)
        return 0x1;  // 3'b001;
    else if (freelist.size() == 0)
        return 0x0;  // 3'b000;
    return 0x0;
}

int fl_new_num(int new_pr_en) {
    switch (new_pr_en) {
        case 0:
            return 0;
        case 1:
            return 1;
        case 2:
            return 1;
        case 3:
            return 2;
        case 4:
            return 1;
        case 5:
            return 2;
        case 6:
            return 2;
        case 7:
            return 3;
        default:
            cerr << "Unkown new_pr_en: " << new_pr_en << endl;
            assert(false);
    }
}

extern "C" int fl_new_pr2(int new_pr_en) {
    if (freelist.size() < 1)
        return 0;
    else
        return freelist[0];
}

extern "C" int fl_new_pr1(int new_pr_en) {
    int new_pr = new_pr_en >> 1;
    if (freelist.size() < 2) return 0;
    switch (new_pr) {
        case 0:
            return 0;
        case 1:
            return freelist.size() >= 1 ? freelist[0] : 0;
        case 2:
            return 0;
        case 3:
            return freelist.size() >= 2 ? freelist[1] : 0;
    }
}

extern "C" int fl_new_pr0(int new_pr_en) {
    switch (new_pr_en) {
        case 0:
            return 0;
        case 1:
            assert(freelist.size() >= 1);
            return freelist[0];
        case 2:
            return 0;
        case 3:
            assert(freelist.size() >= 2);
            return freelist[1];
        case 4:
            return 0;
        case 5:
            assert(freelist.size() >= 2);
            return freelist[1];
        case 6:
            return 0;
        case 7:
            assert(freelist.size() >= 3);
            return freelist[2];
    }
}

extern "C" int fl_pop(int new_pr_en) {
    for (int i = 0; i < fl_new_num(new_pr_en); i++) {
        freelist.pop_front();
    }
    assert(new_pr_en < 8);
}

/* map table simulation */
static vector<int> mapTable;
static vector<int> readyTab;
static bool mt_inited = false;

extern "C" void mt_init() {
    for (int i = 0; i < AR_SIZE; i++) {
        mapTable.push_back(i);
        readyTab.push_back(1);
    }
    mt_inited = true;
    cerr << "MapTable Reseted!" << endl;
}

extern "C" int mt_look_up(int i) {
    if (!mt_inited) return 0;
    assert(i < AR_SIZE);
    if (mt_init) return mapTable[i];
    return 0;
}

extern "C" int mt_look_up_ready(int i) {
    if (!mt_inited) return 0;
    assert(i < AR_SIZE);
    return readyTab[i];
}

extern "C" void mt_map(int ar, int pr) {
    if (!mt_inited) return;
    assert(ar < AR_SIZE);
    if (ar == 0 && pr != 0) {
        cerr << "ERROR: maping AR 0 to PR " << pr << endl;
        return;
    }
    if (pr == 0 && ar != 0) {
        cerr << "ERROR: mapping AR " << ar << " to PR 0" << endl;
        return;
    }
    mapTable[ar] = pr;
    if (ar != 0) readyTab[ar] = 0;
}
