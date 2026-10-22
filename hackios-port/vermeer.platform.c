/*
 * vermeer (Xiaomi Redmi K70, SM8550-AB): paste into xnuloader/loader.c next to
 * platform_redwood and add &platform_vermeer to platforms[].
 *
 * Every value was read from the phone's own device tree
 * (D:\本地项目-01\_k70port_extract\port\Resources\DTBs\vermeer.dtb) or from our Mu-Silicium port;
 * docs/PORTING.md explains where each field comes from, docs/11-HackiOS移植对照.md has the dump.
 */
static const struct platform platform_vermeer = {
	/*
	 * io_base must be non-zero: XNU treats a zero SoC base as "no SoC" and skips clock setup.
	 * One window from 1 MiB to 1 GiB covers everything XNU touches on SM8550:
	 * GCC 0x00100000, TLMM 0x01F00000, UFS 0x01D84000, GIC 0x17100000.
	 */
	.name = "vermeer", .io_base = 0x00100000, .io_size = 0x3FF00000,
	/* arm,gic-v3: reg = <0x17100000 0x10000 0x17180000 0x200000> */
	.gic_dist = 0x17100000, .gic_redist = 0x17180000,
	.uart = 0, .log_other_cpu = 1,
	.psci_hvc = 0,                  /* phones: PSCI over SMC */
	.cores = 8, .core_shift = 8,    /* cpu@0,100,200,...,700 — MPIDR second affinity field */
	/*
	 * cpu@0/100/200 are the little cores (capacity-dmips-mhz = 0x334), cpu@300..600 the gold
	 * ones (0x708), cpu@700 the prime (0x766). A bit per small core, by number: 0,1,2.
	 */
	.timeout_scale = 0,
	.small_cores = 0x7,
	/* What our SimpleFbDxe / GOP reports: 1440x3200 at 0xB8000000 (0x2D00000 bytes reserved). */
	.fb_base = 0xB8000000,
};
