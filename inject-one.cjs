const addonPath = process.argv[2];
const dllPath = process.argv[3];
const pid = parseInt(process.argv[4], 10);

const mod = { exports: {} };
try {
  process.dlopen(mod, addonPath);
} catch (e) {
  console.log('ADDON_LOAD_FAIL ' + e.message);
  process.exit(10);
}
const a = mod.exports;

(async () => {
  console.log('TARGET_PID ' + pid);
  console.log('HAS_LOAD ' + (typeof a.loadModuleManualAsync));

  try {
    const all = await a.getAllMainProcessAsync();
    console.log('ENUM_ALL ' + JSON.stringify(all));
    console.log('ENUM_HAS_TARGET ' + (all || []).includes(pid));
  } catch (e) {
    console.log('ENUM_FAIL ' + e.message);
  }

  try {
    const h = await a.loadModuleManualAsync(pid, dllPath);
    const clean = JSON.stringify(h, (k, v) => (typeof v === 'bigint' ? v.toString() : v));
    console.log('INJECT_OK ' + clean);
  } catch (e) {
    console.log('INJECT_FAIL ' + e.message);
  }

  process.exit(0);
})();