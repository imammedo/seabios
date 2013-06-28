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
        //    \_SB.MTFY(0, 1)
            Notify(L1M0, 0)
        }
        Return(One)
    }

    Method (MRST, 1) {
        If (And(MES, 0x04)) {
            Return(0xF)
        }
        Return(0)
    }

    Method(MCRS, 1) {
        Name(MR64, ResourceTemplate() {
            QWordMemory(ResourceProducer, PosDecode, MinFixed, MaxFixed,
            Cacheable, ReadWrite,
            0x00000000,          // Address Space Granularity
            0x0000000000000000,        // Address Range Minimum
            0xFFFFFFFFFFFFFFFE,        // Address Range Maximum
            0x00000000,          // Address Translation Offset
            0xFFFFFFFFFFFFFFFF,        // Address Length
            ,, MW64, AddressRangeMemory, TypeStatic)
        })

        CreateQWordField(MR64, MW64._MIN, MIN)
        CreateQWordField(MR64, MW64._MAX, MAX)
        CreateQWordField(MR64, MW64._LEN, LEN)

        CreateDWordField(MIN, 0, MINL)
        CreateDWordField(MIN, 4, MINH)
        CreateDWordField(LEN, 0, LENL)
        CreateDWordField(LEN, 4, LENH)
        CreateDWordField(MAX, 0, MAXL)
        CreateDWordField(MAX, 4, MAXH)

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

        Store(MIN, debug)
        Store(LEN, debug)
        Store(MAX, debug)
        Store(MR64, debug)
        Return(MR64)
    }

Device (L1M0)
        {
            Name (_HID, EisaId ("PNP0A05"))
            Name (_UID, 0x10)

    Device(MP00) {
        Name(_UID, 0x0000)
        Name(_HID, EISAID("PNP0C80"))
        //Name(_PXM, 0x00)

        Method(_CRS, 0) {
          Return (\_SB.MCRS(_UID))
        }

        Method (_STA, 0) {
            Return (\_SB.MRST(_UID))
        }
     }
}

}
