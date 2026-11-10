const addonPath = process.argv[2];
const mod = { exports: {} };
try {
  process.dlopen(mod, addonPath);
} catch (e) {
  console.log('ADDON_LOAD_FAIL ' + e.message);
  process.exit(10);
}
const a = mod.exports;
console.log('ADDON_LOADED');
console.log('EXPORTS ' + Object.keys(a).sort().join(','));
(async () => {
  if (typeof a.getAllMainProcessAsync === 'function') {
    try {
      const pids = await a.getAllMainProcessAsync();
      console.log('ENUM_PIDS count=' + (pids ? pids.length : 'null') + ' value=' + JSON.stringify(pids));
    } catch (e) { console.log('ENUM_FAIL ' + e.message); }
  } else { console.log('ENUM_UNSUPPORTED'); }
  if (typeof a.getRuntimeIntegrityAsync === 'function') {
    try {
      const r = await a.getRuntimeIntegrityAsync();
      console.log('INTEGRITY ' + JSON.stringify(r));
    } catch (e) { console.log('INTEGRITY_FAIL ' + e.message); }
  } else { console.log('INTEGRITY_UNSUPPORTED'); }
  if (typeof a.getFileHoldersAsync === 'function') {
    try {
      const r = await a.getFileHoldersAsync(process.argv[3] || 'C:\\Windows\\System32\\kernel32.dll');
      console.log('HOLDERS_SAMPLE ' + JSON.stringify(r).slice(0, 300));
    } catch (e) { console.log('HOLDERS_FAIL ' + e.message); }
  } else { console.log('HOLDERS_UNSUPPORTED'); }
  if (typeof a.loadModuleManualAsync === 'function' && process.argv[4]) {
    try {
      const h = await a.loadModuleManualAsync(parseInt(process.argv[4], 10), process.argv[5]);
      console.log('INJECT_OK ' + JSON.stringify(h, (k, v) => typeof v === 'bigint' ? v.toString() : v));
    } catch (e) { console.log('INJECT_FAIL ' + e.message); }
  } else { console.log('INJECT_SKIPPED'); }
  process.exit(0);
})();