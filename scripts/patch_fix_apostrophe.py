content = open('lib/screens/booking_flow_screen.dart', 'r', encoding='utf-8').read()
n = content.replace('\r\n', '\n')

# Fix 1: unescaped apostrophe in worker's behalf -> use escaped or rephrase
old1 = "? 'Floor Rs.${_workerMinRate!.toInt()} \u00b7 Agent negotiates on worker's behalf'"
new1 = "? 'Floor Rs.${_workerMinRate!.toInt()} \u00b7 AI agent negotiates on behalf of worker'"
n = n.replace(old1, new1, 1)

# Fix 2: remove unused stepIcon variable
old2 = "    final stepIcon = index < _stepIcons.length ? _stepIcons[index] : Icons.circle;\n    final stepEmoji = index < _stepEmojis.length ? _stepEmojis[index] : '\u2022';"
new2 = "    final stepEmoji = index < _stepEmojis.length ? _stepEmojis[index] : '\u2022';"
n = n.replace(old2, new2, 1)

open('lib/screens/booking_flow_screen.dart', 'w', encoding='utf-8').write(n)
print('Fixes applied')

# Verify
if "worker's behalf" in n:
    print('WARNING: apostrophe still present')
else:
    print('OK: apostrophe fixed')
if 'stepIcon' in n:
    print('stepIcon still referenced - check usages')
else:
    print('OK: unused stepIcon removed')
