/****************************************************************
 * Memory hotplug
 ****************************************************************/

Scope(\_SB) {
    /* Objects filled in by run-time generated SSDT */
    External(MTFY, MethodObj)

    /* Memory hotplug notify array */
    OperationRegion(HPMR, SystemIO, 0xaf80, 32)
    Field (HPMR, DWordAcc, NoLock, WriteAsZeros)
    {
        MRBL, 32,
        MRBH, 32,
        MRLL, 32,
        MRLH, 32,
    }
    Field (HPMR, ByteAcc, NoLock, WriteAsZeros)
    {
        Offset(0x10),
        MES, 8,
    }

    Method(MESC, 0) {
        If (And(MES, 0x04)) { // onlining ?
            \_SB.MTFY(0, 1)
        }
        Return(One)
    }

    Method (MRST, 1) {
        Store("MRST", debug)
        If (And(MES, 0x04)) {
            Store(0xF, debug)
            Return(0xF)
        }
        Return(0)
    }

    Method(MCRS, 1) {
        Store("MCRS", debug)
        Name(MR64, ResourceTemplate() {
            QWordMemory(ResourceProducer, PosDecode, MinFixed, MaxFixed,
            Cacheable, ReadWrite,
            0x0000000000000000,        // Address Space Granularity
            0x0000000000000000,        // Address Range Minimum
            0xFFFFFFFFFFFFFFFE,        // Address Range Maximum
            0x0000000000000000,        // Address Translation Offset
            0xFFFFFFFFFFFFFFFF,        // Address Length
            ,, MW64, AddressRangeMemory, TypeStatic)
        })

        CreateDWordField(MR64, 14, MINL)
        CreateDWordField(MR64, 18, MINH)
        CreateDWordField(MR64, 38, LENL)
        CreateDWordField(MR64, 42, LENH)
        CreateDWordField(MR64, 22, MAXL)
        CreateDWordField(MR64, 26, MAXH)

        Store(MRBH, MINH)
        Store(MRBL, MINL)
        Store(MRLH, LENH)
        Store(MRLL, LENL)

        // 64-bit math: MAX = MIN + LEN - 1
        Add(MINL, LENL, MAXL)
        Add(MINH, LENH, MAXH)
        If (Or(LLess(MAXL, MINL), LLess(MAXL, LENL))) {
            Add(MAXH, 1, MAXH)
        }
        If (LEqual(MAXL, Zero)) {
            Subtract(MAXH, One, MAXH)
            Store(0xFFFFFFFF, MAXL)
        } Else {
            Subtract(MAXL, One, MAXL)
        }

        Return(MR64)
    }
}
