// Denoの標準的なURLインポートを利用
import * as bip39 from "@iacobus/bip39";
import { english } from "@iacobus/bip39/wordlist/english";

function generate(): string {
	return bip39.generateMnemonic(english, 24);
}

const numberOfNodes = Deno.args.length > 0 ? parseInt(Deno.args[0]) : 2;

console.log(`---`);
console.log(`apiVersion: v1`);
console.log(`kind: Secret`);
console.log(`metadata:`);
console.log(`  name: gaia-mnemonics`);
console.log(`stringData:`);

for (let i = 0; i < numberOfNodes; i++) {
	console.log(`  MNEMONIC_${i}: "${generate()}"`);
	console.log(`  RELAYER_MNEMONIC_${i}: "${generate()}"`);
}