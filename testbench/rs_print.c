#include <stdio.h>
#define NOOP_INST 0x00000013
void print_select(int index,  int valid, int fu_sel,  int npc, int fu_select, int op_select) {
  printf("|  %1d  |", index);
  print_stage("", fu_sel, npc, valid);
  char *fu;
  char *op;
  switch(fu_select){
    case 0: fu = " ALU_1"; break;
    case 1: fu = " ALU_2"; break;
    case 2: fu = " ALU_3"; break;
    case 3: fu = " LS_1 "; break;
    case 4: fu = " LS_2 "; break;
    case 5: fu = "MULT_1"; break;
    case 6: fu = "MULT_2"; break;
    case 7: fu = "BRANCH"; break;
    default: fu = "  x   "; break;
  }
  switch(op_select) {
    case 0: op = "ADD"; break;
    case 1: op = "SUB"; break;
    case 2: op = "AND"; break;
    case 3: op = "SLT"; break;
    case 4: op = "SLTU"; break;
    case 5: op = "OR "; break;
    case 6: op = "XOR"; break;
    case 7: op = "SRL"; break;
    case 8: op = "SLL"; break;
    case 9: op = "SRA"; break;
    default: fu = " x "; break;
  }
  printf("| %s |   %s   |\n", fu, op);
}


void print_stage(char* div, int fu_sel, int npc, int valid_inst)
{
  int opcode, funct3, funct7, funct12;
  char *str;

  if(!valid_inst)
    str = "-";
  else if(fu_sel<0)
    str = "nop";
  else{
    if (fu_sel<3)
    {
      str = "alu";
    }
    else if (fu_sel<5)
    {
      str = "ls";
    }
    else if (fu_sel<7)
    {
      str = "mult";
    }
    else {
      str = "branch";
    }
  }
  
  
  

  /*
  if(!valid_inst)
    str = "-";
  else if(inst==NOOP_INST)
    str = "nop";
  else {
    opcode = inst & 0x7f;
    funct3 = (inst>>12) & 0x7;
    funct7 = inst>>25;
    funct12 = inst>>20; // for system instructions
    // See the RV32I base instruction set table
    switch (opcode) {
    case 0x37: str = "lui"; break;
    case 0x17: str = "auipc"; break;
    case 0x6f: str = "jal"; break;
    case 0x67: str = "jalr"; break;
    case 0x63: // branch
      switch (funct3) {
      case 0b000: str = "beq"; break;
      case 0b001: str = "bne"; break;
      case 0b100: str = "blt"; break;
      case 0b101: str = "bge"; break;
      case 0b110: str = "bltu"; break;
      case 0b111: str = "bgeu"; break;
      default: str = "invalid"; break;
      }
      break;
    case 0x03: // load
      switch (funct3) {
      case 0b000: str = "lb"; break;
      case 0b001: str = "lh"; break;
      case 0b010: str = "lw"; break;
      case 0b100: str = "lbu"; break;
      case 0b101: str = "lhu"; break;
      default: str = "invalid"; break;
      }
      break;
    case 0x23: // store
      switch (funct3) {
      case 0b000: str = "sb"; break;
      case 0b001: str = "sh"; break;
      case 0b010: str = "sw"; break;
      default: str = "invalid"; break;
      }
      break;
    case 0x13: // immediate
      switch (funct3) {
      case 0b000: str = "addi"; break;
      case 0b010: str = "slti"; break;
      case 0b011: str = "sltiu"; break;
      case 0b100: str = "xori"; break;
      case 0b110: str = "ori"; break;
      case 0b111: str = "andi"; break;
      case 0b001:
        if (funct7 == 0x00) str = "slli";
        else str = "invalid";
        break;
      case 0b101:
        if (funct7 == 0x00) str = "srli";
        else if (funct7 == 0x20) str = "srai";
        else str = "invalid";
        break;
      }
      break;
    case 0x33: // arithmetic
      switch (funct7 << 4 | funct3) {
      case 0x000: str = "add"; break;
      case 0x200: str = "sub"; break;
      case 0x001: str = "sll"; break;
      case 0x002: str = "slt"; break;
      case 0x003: str = "sltu"; break;
      case 0x004: str = "xor"; break;
      case 0x005: str = "srl"; break;
      case 0x205: str = "sra"; break;
      case 0x006: str = "or"; break;
      case 0x007: str = "and"; break;
      // M extension
      case 0x010: str = "mul"; break;
      case 0x011: str = "mulh"; break;
      case 0x012: str = "mulhsu"; break;
      case 0x013: str = "mulhu"; break;
      case 0x014: str = "div"; break;  // unimplemented
      case 0x015: str = "divu"; break; // unimplemented
      case 0x016: str = "rem"; break;  // unimplemented
      case 0x017: str = "remu"; break; // unimplemented
      default: str = "invalid"; break;
      }
      break;
    case 0x0f: str = "fence"; break; // unimplemented, imprecise 
    case 0x73:
      switch (funct3) {
      case 0b000:
        // unimplemented, somewhat inaccurate :(
        switch (funct12) {
        case 0x000: str = "ecall"; break;
        case 0x001: str = "ebreak"; break;
        case 0x105: str = "wfi"; break; // we just mostly care about this
        default: str = "system"; break;
        }
        break;
      case 0b001: str = "csrrw"; break;
      case 0b010: str = "csrrs"; break;
      case 0b011: str = "csrrc"; break;
      case 0b101: str = "csrrwi"; break;
      case 0b110: str = "csrrsi"; break;
      case 0b111: str = "csrrci"; break;
      default: str = "invalid"; break;
      }
      break;
    default: str = "invalid"; break;
    }
  }
  */
    printf("%s%4x:%-8s", div, npc, str);
}