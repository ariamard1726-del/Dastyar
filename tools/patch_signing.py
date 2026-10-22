import os
import re
import sys

store = os.environ.get('KEYSTORE_PATH', '')
pw = os.environ.get('KEYSTORE_PASSWORD', '')
KTS = 'android/app/build.gradle.kts'
GROOVY = 'android/app/build.gradle'

if not store or not pw:
    print('No keystore or password; the temporary debug key stays.')
    sys.exit(0)
if re.search(r'[\\\s=#!:]', pw):
    print('Password has a space or one of \\ = # ! : ; signing skipped.')
    sys.exit(0)

with open('android/key.properties', 'w') as f:
    f.write('storePassword=%s\nkeyPassword=%s\nkeyAlias=dastyar\nstoreFile=%s\n' % (pw, pw, store))

KTS_BLOCK = '''    signingConfigs {
        create("release") {
            val props = java.util.Properties()
            val pf = rootProject.file("key.properties")
            if (pf.exists()) {
                java.io.FileInputStream(pf).use { props.load(it) }
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
        print('Already patched:', path)
        return True
    m = re.search(r'^[ \t]*buildTypes\s*\{', text, re.M)
    if not m or not re.search(pattern, text):
        return False
    text = text[:m.start()] + block + text[m.start():]
    text = re.sub(pattern, repl, text)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(text)
    return True


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
    print('Signing patched. Relevant lines:')
    with open(path, encoding='utf-8') as f:
        for line in f:
            if 'signingConfig' in line or 'key.properties' in line:
                print('  ' + line.rstrip())
else:
    print('Could not patch the gradle file; the debug key stays.')
