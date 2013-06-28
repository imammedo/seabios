/****************************************************************
 * Memory hotplug
 ****************************************************************/

Scope(\_SB) {
        /* Objects filled in by run-time generated SSDT */
        External(MTFY, MethodObj)

       /* Memory hotplug notify array */
        OperationRegion(MEST, SystemIO, 0xaf80, 3)
        Field (MEST, ByteAcc, NoLock, WriteAsZeros)
        {
            MES, 8,
            MER, 8,
            MOS, 8
        }

        Method(MESC, 0) {
            If (And(MES, 0x04)) { // onlining ?
		\_SB.MTFY(0, 1)
            }
            Return(One)
        }

    Name(MR64, ResourceTemplate() {
         QWordMemory(ResourceProducer, PosDecode, MinFixed, MaxFixed,
            Cacheable, ReadWrite,
            0x00000000,          // Address Space Granularity
            0x8000000000,        // Address Range Minimum
            0xFFFFFFFFFF,        // Address Range Maximum
            0x00000000,          // Address Translation Offset
            0x8000000000,        // Address Length
            ,, MW64, AddressRangeMemory, TypeStatic)
    })
 
    Device(MP00) {
        Name(ID, 0x00)
        Name(_HID, EISAID("PNP0C80"))
        Name(_PXM, 0x00)

        Method(_CRS) {
          Name(RTM, ResourceTemplate() {
            QwordMemory(
               ResourceProducer,
               ,                     // _DEC
               MinFixed,             // _MIF
               MaxFixed,             // _MAF
               Cacheable,            // _MEM
               ReadWrite,            // _RW
               0x0,                  // _GRA
               0x40000000,           // _MIN
               0x7fffffff,           // _MAX
               0x00000000,           // _TRA
               0x40000000,           // _LEN
               )
          })
                Store(0xFF, MER)
          Return (RTM)
        }

        Method (_STA, 0) {
            If (And(MES, 0x04)) {
                Return(0xFF)
            } Else {
                Return(0)
            }
        }
        
       Method (_OST, 3, Serialized) {
                Store(Arg0, MOS)
                Store(Arg1, MOS)
       }
     }


}
