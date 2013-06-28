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
        If (And(MES, 0x04)) {
            Return(0xFF)
        }
        Return(0)
    }

    Method(MCRS, 1) {
        Name(MR64, ResourceTemplate() {
            QWordMemory(ResourceProducer, PosDecode, MinFixed, MaxFixed,
            Cacheable, ReadWrite,
            0x00000000,          // Address Space Granularity
            0x0000000000,        // Address Range Minimum
            0xFFFFFFFFFF,        // Address Range Maximum
            0x00000000,          // Address Translation Offset
            0xFFFFFFFFFE,        // Address Length
            ,, MW64, AddressRangeMemory, TypeStatic)
        })

        CreateQWordField(MR64, MW64._MIN, MIN)
        CreateQWordField(MR64, MW64._MAX, MAX)
        CreateQWordField(MR64, MW64._LEN, LEN)

        Or(ShiftLeft(MRBH, 32),MRBL, MIN)
        Or(ShiftLeft(MRLH, 32), MRLL, LEN)
        Add(MIN, Subtract(LEN, 1), MAX)

        Return (MR64)
    }

    Device(MP00) {
        Name(ID, 0x00)
        Name(_HID, EISAID("PNP0C80"))
        Name(_PXM, 0x00)

        Method(_CRS, 0) {
          Return (\_SB.MCRS(ID))
        }

        Method (_STA, 0) {
            Return (\_SB.MRST(ID))
        }
     }

}
