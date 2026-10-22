// Scan extracted Qualcomm images for device-tree evidence.
const fs = require('fs');
const path = require('path');

const files = process.argv.slice(2);
const markers = [
  'init_speed_params',
  'perf_speed_params',
  'timeout_values',
  'ufs0_vcc',
  '/soc/ufs0',
  'ufshc',
  'DtbExtn',
  'DTBExtn',
  'qcom,ufs-phy',
];

for (const f of files) {
  if (!fs.existsSync(f)) { console.log(`--- ${f}: MISSING`); continue; }
  const buf = fs.readFileSync(f);
  console.log(`\n=== ${path.basename(f)}  ${buf.length} bytes  sha-free`);

  // FDT magic 0x00D00DFEED big-endian
  const fdt = [];
  for (let i = 0; i + 4 <= buf.length; i++) {
    if (buf[i] === 0xd0 && buf[i+1] === 0x0d && buf[i+2] === 0xfe && buf[i+3] === 0xed) {
      fdt.push('0x' + i.toString(16));
      if (fdt.length >= 12) break;
    }
  }
  console.log(`  FDT magic hits: ${fdt.length ? fdt.join(' ') : 'NONE'}`);

  for (const m of markers) {
    const hits = [];
    let idx = 0;
    while (hits.length < 4) {
      const p = buf.indexOf(m, idx, 'latin1');
      if (p < 0) break;
      hits.push('0x' + p.toString(16));
      idx = p + 1;
    }
    console.log(`  ${m.padEnd(20)} ${hits.length ? hits.join(' ') : 'NONE'}`);
  }
}
