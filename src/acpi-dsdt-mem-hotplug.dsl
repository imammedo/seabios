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
            0xAB000000CD,        // Address Range Minimum
            0xFAFFFFFFFE,        // Address Range Maximum
            0x00000000,          // Address Translation Offset
            0xFDFFFFFFFE,        // Address Length
            ,, MW64, AddressRangeMemory, TypeStatic)
        })

        CreateQWordField(MR64, MW64._MIN, MIN)
        CreateQWordField(MR64, MW64._MAX, MAX)
        CreateQWordField(MR64, MW64._LEN, LEN)

	Store(MR64, debug)

        Or(ShiftLeft(MRBH, 32),MRBL, MIN)
        Or(ShiftLeft(MRLH, 32), MRLL, LEN)
        Add(MIN, Subtract(LEN, 1), MAX)

        Store(MIN, Local0)
        Store(LEN, Local1)
        Store(Zero, Local3)
        Store(Zero, Local4)
        while (LNotEqual(Local1, 0)) {
            Store(Local0, MIN)
            if (LGreater (Local1, 0xC0000000)) {
                Store(0xC0000000, LEN)
            } else {
                Store(Local1, LEN)
            }
            Subtract(Add(Local0, LEN), 1, MAX)
            Add(LEN, Local0, Local0)
            Subtract(Local1, LEN, Local1)

            if (LEqual(Local4, Zero)) {
                Store(MR64, Local2)
                Store(One, Local4)
            } else {
                ConcatenateResTemplate(Local2, MR64, Local2)
            }

            Add(Local3, 1, Local3)
        //    Store(MIN, debug)
        //    Store(MAX, debug)
        //    Store(LEN, debug)
        //    Store(Local2,debug)
        }

        Store(Local2,debug)
        Store(SizeOf(Local2),debug)
        Store(Local3,debug)
        Return(Local2)
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
