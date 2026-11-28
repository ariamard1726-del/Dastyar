"""پیکربندی امضای نسخهٔ انتشار برای ساخت در CI (build.yml).

کلید از Secrets رمزگشایی می‌شود (KEYSTORE_PATH) و این اسکریپت تنظیمات
امضای release را در android/app/build.gradle تزریق می‌کند.
(نام قبلی: patch_signing.py)
"""
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
KTS = os.path.join(ROOT, 'android', 'app', 'build.gradle.kts')
GROOVY = os.path.join(ROOT, 'android', 'app', 'build.gradle')
PROGUARD = os.path.join(ROOT, 'android', 'app', 'proguard-rules.pro')
GITIGNORE = os.path.join(ROOT, 'android', '.gitignore')
EXAMPLE = os.path.join(ROOT, 'android', 'key.properties.example')


def check_release_signing():
    """بررسی پیکربندی غیرمخفی امضای انتشار، ProGuard و حفاظت کلیدها."""
    errors = []
    if not os.path.isfile(KTS):
        errors.append('android/app/build.gradle.kts پیدا نشد')
    else:
        with open(KTS, encoding='utf-8') as f:
            kts = f.read()
        for needle in (
            'rootProject.file("key.properties")',
            'ALLOW_DEBUG_SIGNING',
            'isMinifyEnabled = true',
            'isShrinkResources = true',
            'proguard-rules.pro',
            'throw GradleException',
        ):
            if needle not in kts:
                errors.append(f'build.gradle.kts فاقد قاعدهٔ انتشار است: {needle}')
    if not os.path.isfile(PROGUARD) or os.path.getsize(PROGUARD) == 0:
        errors.append('android/app/proguard-rules.pro پیدا نشد یا خالی است')
    if not os.path.isfile(GITIGNORE):
        errors.append('android/.gitignore پیدا نشد')
    else:
        with open(GITIGNORE, encoding='utf-8') as f:
            gi = f.read()
        for pat in ('key.properties', '**/*.keystore', '**/*.jks'):
            if pat not in gi:
                errors.append(f'android/.gitignore فاقد {pat} است')
    if not os.path.isfile(EXAMPLE):
        errors.append('android/key.properties.example پیدا نشد')
    else:
        with open(EXAMPLE, encoding='utf-8') as f:
            ex = f.read()
        for key in ('storePassword=', 'keyPassword=', 'keyAlias=', 'storeFile='):
            if key not in ex:
                errors.append(f'android/key.properties.example فاقد {key} است')
    return errors


def main():
    if '--check' in sys.argv:
        errs = check_release_signing()
        if errs:
            print('خطای پیکربندی امضای انتشار اندروید:\n  ' + '\n  '.join(errs))
            return 1
        print('signing-check OK: build.gradle.kts، proguard-rules.pro، .gitignore و نمونهٔ key.properties آماده‌اند.')
        return 0

    store = os.environ.get('KEYSTORE_PATH', '')
    pw = os.environ.get('KEYSTORE_PASSWORD', '')
    key_pw = os.environ.get('KEY_PASSWORD', '') or pw
    alias = os.environ.get('KEY_ALIAS', '').strip()

    if not store or not pw:
        print('No keystore or password; the temporary debug key stays.')
        return 0
    if re.search(r'[\\\s=#!:]', pw) or re.search(r'[\\\s=#!:]', key_pw):
        print('ERROR: bad password chars; signing NOT applied.')
        return 1

    if not alias:
        try:
            out = subprocess.check_output(
                ['keytool', '-list', '-keystore', store, '-storepass', pw],
                text=True,
                stderr=subprocess.DEVNULL,
            )
            for line in out.splitlines():
                if 'PrivateKeyEntry' in line and ',' in line:
                    alias = line.split(',', 1)[0].strip()
                    break
        except Exception:
            pass
    if not alias:
        alias = 'dastyar'

    with open('android/key.properties', 'w', encoding='utf-8') as f:
        f.write(
            'storePassword=%s\nkeyPassword=%s\nkeyAlias=%s\nstoreFile=%s\n'
            % (pw, key_pw, alias, store)
        )

    ok = False
    if os.path.exists(KTS):
        ok = patch(
            KTS,
            KTS_BLOCK,
            r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)',
            'signingConfig = signingConfigs.getByName("release")',
        )
        path = KTS
    elif os.path.exists(GROOVY):
        ok = patch(
            GROOVY,
            GROOVY_BLOCK,
            r'signingConfig\s*=?\s*signingConfigs\.debug',
            'signingConfig signingConfigs.release',
        )
        path = GROOVY

    if ok:
        print(f'Signing configured (alias={alias}). Relevant lines:')
        with open(path, encoding='utf-8') as f:
            for line in f:
                if 'signingConfig' in line or 'key.properties' in line:
                    print('  ' + line.rstrip())
        return 0
    print('ERROR: gradle not patched; refusing debug-signed APK.')
    return 1


KTS_BLOCK = '''    signingConfigs {
        create("release") {
            val props = Properties()
            val pf = rootProject.file("key.properties")
            if (pf.exists()) {
                FileInputStream(pf).use { props.load(it) }
                storeFile = file(props.getProperty("storeFile"))
                storePassword = props.getProperty("storePassword")
                keyAlias = props.getProperty("keyAlias")
                keyPassword = props.getProperty("keyPassword")
            }
        }
    }

'''

GROOVY_BLOCK = '''    signingConfigs {
        release {
            def props = new java.util.Properties()
            def pf = rootProject.file('key.properties')
            if (pf.exists()) {
                props.load(new java.io.FileInputStream(pf))
                storeFile file(props['storeFile'])
                storePassword props['storePassword']
                keyAlias props['keyAlias']
                keyPassword props['keyPassword']
            }
        }
    }

'''


def patch(path, block, pattern, repl):
    with open(path, encoding='utf-8') as f:
        text = f.read()
    if 'key.properties' in text:
        print('Already configured for key.properties:', path)
        return True
    m = re.search(r'^[ \t]*buildTypes\s*\{', text, re.M)
    if not m or not re.search(pattern, text):
        return False

    if path.endswith('.kts'):
        imports_needed = []
        if 'import java.util.Properties' not in text:
            imports_needed.append('import java.util.Properties')
        if 'import java.io.FileInputStream' not in text:
            imports_needed.append('import java.io.FileInputStream')
        if imports_needed:
            text = '\n'.join(imports_needed) + '\n\n' + text

    m = re.search(r'^[ \t]*buildTypes\s*\{', text, re.M)
    if not m:
        return False
    text = text[:m.start()] + block + text[m.start():]
    text = re.sub(pattern, repl, text)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(text)
    return True


if __name__ == '__main__':
    raise SystemExit(main())
