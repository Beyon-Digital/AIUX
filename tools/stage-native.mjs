// Assemble native CI artifacts without compiling Rust on the operator's host.
// Usage: node tools/stage-native.mjs <apple-artifacts> <android-artifacts>
import { cpSync, mkdirSync, rmSync } from 'node:fs';
import { resolve } from 'node:path';
import { execFileSync } from 'node:child_process';
const [apple, android] = process.argv.slice(2).map(p => resolve(p));
if (!apple || !android) throw new Error('Expected Apple and Android artifact directories');
const ios = 'bridges/expo/ios/vendor';
rmSync(ios, { recursive: true, force: true });
mkdirSync(`${ios}/staged/AIUXCore`, { recursive: true });
execFileSync('unzip', ['-q', `${apple}/AIUXCore.xcframework.zip`, '-d', ios]);
execFileSync('tar', ['-xzf', `${apple}/aiux-swift-bindings.tar.gz`, '-C', ios]);
cpSync(`${ios}/Sources/AIUXCore/AIUXCore.swift`, `${ios}/staged/AIUXCore/AIUXCore.swift`);
rmSync(`${ios}/Sources`, { recursive: true });
rmSync(`${ios}/Package.swift`, { force: true });
cpSync('renderers/swiftui/Sources/AIUXSwiftUI', `${ios}/staged/AIUXSwiftUI`, { recursive: true });
const dest = 'bridges/expo/android/vendor';
rmSync(dest, { recursive: true, force: true });
mkdirSync(dest, { recursive: true });
execFileSync('tar', ['-xzf', `${android}/aiux-android-maven.tar.gz`, '-C', dest]);
console.log('Expo now contains Swift bindings, renderer, XCFramework and Android Maven artifacts');
