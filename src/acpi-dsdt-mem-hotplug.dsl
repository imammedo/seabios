/****************************************************************
 * Memory hotplug
 ****************************************************************/

Scope(\_SB) {
    /* Objects filled in by run-time generated SSDT */
    External(MTFY, MethodObj)
    External(MDNR, IntObj)

    /* Memory hotplug notify array */
    OperationRegion(HPMR, SystemIO, 0xaf80, 32)
    Field (HPMR, DWordAcc, NoLock, Preserve)
    {
        MRBL, 32, // DIMM start addr Low word, read only
        MRBH, 32, // DIMM start addr Hi word, read only
        MRLL, 32, // DIMM size Low word, read only
        MRLH, 32, // DIMM size Hi word, read only
        MPX, 32,  // DIMM node proximity, read only
    }
    Field (HPMR, ByteAcc, NoLock, Preserve)
    {
        Offset(20),
        MVER, 8, // Interface version
        MES,  1, // 1 if DIMM enabled for _STA, read only
        MINS, 1, // 1 if DIMM has a insert event, read only
        MRMV, 1, // 1 if DIMM has a remove request, read only
    }

    Mutex (MLCK, 0)
    Field (HPMR, DWordAcc, NoLock, Preserve)
    {
        MSEL, 32,  // DIMM selector, write only
        MOEV, 32,  // _OST event code, write only
        MOSC, 32,  // _OST status code, write only
    }

    Method(MESC, 0) {
        Store(Zero, Local0) // Mem devs iterrator

        Acquire(MLCK, 0xFFFF)
        while (LLess(Local0, MDNR)) {
            Store(Local0, MSEL) // select Local0 DIMM
            If (LEqual(MINS, One)) { // Memory device needs check
                \_SB.MTFY(Local0, 1)
            }
            If (LEqual(MRMV, One)) { // Ejection request
                \_SB.MTFY(Local0, 3)
            }
            Add(Local0, One, Local0) // goto next DIMM
        }
        Release(MLCK)
        Return(One)
    }

    Method (MRST, 1) {
        Store(Zero, Local0)

        Acquire(MLCK, 0xFFFF)
        Store(ToInteger(Arg0), MSEL) // select DIMM

        If (LEqual(MES, One)) {
            Store(0xF, Local0)
        }

        Release(MLCK)
        Return(Local0)
    }

    Method(MCRS, 1) {
        Acquire(MLCK, 0xFFFF)
        Store(ToInteger(Arg0), MSEL) // select DIMM

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

        Release(MLCK)
        Return(MR64)
    }

    Method (MPXM, 1) {
        Acquire(MLCK, 0xFFFF)
        Store(ToInteger(Arg0), MSEL) // select DIMM
        Store(MPX, Local0)
        Release(MLCK)
        Return(Local0)
    }

    Method(MOST, 4) {
        Acquire(MLCK, 0xFFFF)
        Store(ToInteger(Arg0), MSEL) // select DIMM
        Store(Arg1, MOEV)
        Store(Arg2, MOSC)
        Release(MLCK)
    }
}
