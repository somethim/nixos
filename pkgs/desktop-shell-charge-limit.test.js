// Run: node pkgs/desktop-shell-charge-limit.test.js <patched shell/plugins/panels/power/Model.js>
const assert = require("assert")
const m = require(require("path").resolve(process.argv[2]))
assert.deepStrictEqual(m.parseChargeLimit("b true\nb false\n"), { supported: true, enabled: false })
assert.deepStrictEqual(m.parseChargeLimit("b true\nb true\n"), { supported: true, enabled: true })
assert.deepStrictEqual(m.parseChargeLimit("b false\nb false\n"), { supported: false, enabled: false })
assert.deepStrictEqual(m.parseChargeLimit(""), { supported: false, enabled: false })
console.log("ok")
