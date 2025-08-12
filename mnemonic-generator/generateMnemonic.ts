import * as bip39 from 'bip39';

// 24単語のニーモニックを1つ生成するヘルパー関数
function generate(): string {
	return bip39.generateMnemonic(256);
}

// 4つのニーモニックを生成し、環境変数形式で出力
console.log(`MNEMONIC_1=${generate()}`);
console.log(`RELAYER_MNEMONIC_1=${generate()}`);
console.log(`MNEMONIC_2=${generate()}`);
console.log(`RELAYER_MNEMONIC_2=${generate()}`);