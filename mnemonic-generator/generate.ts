// Denoの標準的なURLインポートを利用
import * as bip39 from "@iacobus/bip39";
import { english } from "@iacobus/bip39/wordlist/english";

// 24単語のニーモニックを1つ生成するヘルパー関数
function generate(): string {
	return bip39.generateMnemonic(english, 24);
}

// 4つのニーモニックを生成し、環境変数形式で出力
// ★★★ 修正点：値にスペースが含まれるため、シングルクオートではなくダブルクオートで囲む ★★★
console.log(`MNEMONIC_1="${generate()}"`);
console.log(`RELAYER_MNEMONIC_1="${generate()}"`);
console.log(`MNEMONIC_2="${generate()}"`);
console.log(`RELAYER_MNEMONIC_2="${generate()}"`);