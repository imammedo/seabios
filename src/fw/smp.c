// QEMU multi-CPU initialization code
//
// Copyright (C) 2008  Kevin O'Connor <kevin@koconnor.net>
// Copyright (C) 2006 Fabrice Bellard
//
// This file may be distributed under the terms of the GNU LGPLv3 license.

#include "config.h" // CONFIG_*
#include "hw/rtc.h" // CMOS_BIOS_SMP_COUNT
#include "output.h" // dprintf
#include "romfile.h" // romfile_loadint
#include "stacks.h" // yield
#include "util.h" // smp_setup
#include "x86.h" // wrmsr

#define APIC_ICR_LOW ((u8*)BUILD_APIC_ADDR + 0x300)
#define APIC_SVR     ((u8*)BUILD_APIC_ADDR + 0x0F0)
#define APIC_LINT0   ((u8*)BUILD_APIC_ADDR + 0x350)
#define APIC_LINT1   ((u8*)BUILD_APIC_ADDR + 0x360)

#define APIC_ENABLED 0x0100
#define MSR_IA32_APIC_BASE 0x01B
#define MSR_LOCAL_APIC_ID 0x802
#define MSR_IA32_APICBASE_EXTD (1ULL << 10) /* Enable x2APIC mode */

static struct { u32 index; u64 val; } smp_mtrr[32];
static u32 smp_mtrr_count;

void
wrmsr_smp(u32 index, u64 val)
{
    wrmsr(index, val);
    if (smp_mtrr_count >= ARRAY_SIZE(smp_mtrr)) {
        warn_noalloc();
        return;
    }
    smp_mtrr[smp_mtrr_count].index = index;
    smp_mtrr[smp_mtrr_count].val = val;
    smp_mtrr_count++;
}

u32 MaxCountCPUs;
static u32 CountCPUs;
// 256 bits for the found APIC IDs
static u32 FoundAPICIDs[256/32];

int apic_id_is_present(u8 apic_id)
{
    return !!(FoundAPICIDs[apic_id/32] & (1ul << (apic_id % 32)));
}

static void handle_x2apic(u32 has_x2apic)
{
    if (MaxCountCPUs < 256)
        return;

    if (!has_x2apic)
        return;

    // switch to x2APIC mode
    u64 apic_base = rdmsr(MSR_IA32_APIC_BASE);
    wrmsr(MSR_IA32_APIC_BASE, apic_base | MSR_IA32_APICBASE_EXTD);
}

void VISIBLE32FLAT
handle_smp(void)
{
    if (!CONFIG_QEMU)
        return;

    // Detect apic_id
    u32 eax, ebx, ecx, cpuid_features;
    cpuid(1, &eax, &ebx, &ecx, &cpuid_features);

    handle_x2apic(ecx & CPUID_X2APIC);

    // MTRR setup
    int i;
    for (i=0; i<smp_mtrr_count; i++)
        wrmsr(smp_mtrr[i].index, smp_mtrr[i].val);

    /*
     * QEMU that supports APIC ID > 255 provides its own BIOS tables
     * so skip filling present APIC map as it's not used.
     * (it's used for internal BIOS tables for QEMU older than 1.8)
     */
    if (MaxCountCPUs < 255) {
       u32 apic_id = ebx>>24;
       // Set bit on FoundAPICIDs
       FoundAPICIDs[apic_id/32] |= (1 << (apic_id % 32));
    }
    CountCPUs++;
}

// Atomic lock for shared stack across processors.
u32 SMPLock __VISIBLE;
u32 SMPStack __VISIBLE;

// find and initialize the CPUs by launching a SIPI to them
void
smp_setup(void)
{
    if (!CONFIG_QEMU)
        return;

    ASSERT32FLAT();
    u32 eax, ebx, ecx, cpuid_features;
    cpuid(1, &eax, &ebx, &ecx, &cpuid_features);
    if (eax < 1 || !(cpuid_features & CPUID_APIC)) {
        // No apic - only the main cpu is present.
        dprintf(1, "No apic - only the main cpu is present.\n");
        CountCPUs= 1;
        MaxCountCPUs = 1;
        return;
    }

    /* set max possible APIC ID limit for AP bootstrap to decide
     * if it neds to switch into x2APIC mode
     */
    MaxCountCPUs = romfile_loadint("etc/max-cpus", 1);

    // mark the BSP initial APIC ID as found, too:
    u8 apic_id = ebx>>24;
    FoundAPICIDs[apic_id/32] |= (1 << (apic_id % 32));
    CountCPUs = 1;

    // Setup jump trampoline to counter code.
    u64 old = *(u64*)BUILD_AP_BOOT_ADDR;
    // ljmpw $SEG_BIOS, $(entry_smp - BUILD_BIOS_ADDR)
    extern void entry_smp(void);
    u64 new = (0xea | ((u64)SEG_BIOS<<24)
               | (((u32)entry_smp - BUILD_BIOS_ADDR) << 8));
    *(u64*)BUILD_AP_BOOT_ADDR = new;

    // enable local APIC
    u32 val = readl(APIC_SVR);
    writel(APIC_SVR, val | APIC_ENABLED);

    /* Set LINT0 as Ext_INT, level triggered */
    writel(APIC_LINT0, 0x8700);

    /* Set LINT1 as NMI, level triggered */
    writel(APIC_LINT1, 0x8400);

    // Init the lock.
    writel(&SMPLock, 1);

    // broadcast SIPI
    barrier();
    writel(APIC_ICR_LOW, 0x000C4500);
    u32 sipi_vector = BUILD_AP_BOOT_ADDR >> 12;
    writel(APIC_ICR_LOW, 0x000C4600 | sipi_vector);

    // Wait for other CPUs to process the SIPI.
    u16 boot_cpus_count = romfile_loadint("etc/boot-cpus",
                                          rtc_read(CMOS_BIOS_SMP_COUNT) + 1);
    while (boot_cpus_count != CountCPUs)
        asm volatile(
            // Release lock and allow other processors to use the stack.
            "  movl %%esp, %1\n"
            "  movl $0, %0\n"
            // Reacquire lock and take back ownership of stack.
            "1:rep ; nop\n"
            "  lock btsl $0, %0\n"
            "  jc 1b\n"
            : "+m" (SMPLock), "+m" (SMPStack)
            : : "cc", "memory");
    yield();

    // Restore memory.
    *(u64*)BUILD_AP_BOOT_ADDR = old;

    handle_x2apic(ecx & CPUID_X2APIC);

    if (MaxCountCPUs < CountCPUs)
        MaxCountCPUs = CountCPUs;

    dprintf(1, "Found %d cpu(s) max supported %d cpu(s)\n", CountCPUs,
            MaxCountCPUs);
}
