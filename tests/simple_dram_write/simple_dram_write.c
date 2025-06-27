int main()
{
    unsigned int address = 0x80000000;
    unsigned int offset = 0x12345128;
    unsigned int value = 0xDEADBEEF;
    *((volatile unsigned int*)(address + offset)) = value;
    
    return 0;
}
