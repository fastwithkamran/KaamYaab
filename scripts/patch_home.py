import re

content = open('lib/screens/home_screen.dart', 'r', encoding='utf-8').read()
n = content.replace('\r\n', '\n').replace('\r', '\n')
changes = 0

# 1. Ensure dart:async is imported
if "import 'dart:async';" not in n:
    n = "import 'dart:async';\n" + n
    changes += 1
    print('Added dart:async import')

# 2. Replace AI loading indicator
old_loading = "                    // AI Loading Indicator\n                    if (_isAILoading)\n                      const SliverToBoxAdapter(\n                        child: Padding(\n                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),\n                          child: Row(children: [\n                            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.tealPrimary)),\n                            SizedBox(width: 12),\n                            Text('Agent is thinking...', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),\n                          ]),\n                        ),\n                      ),"
new_loading = "                    // AI Agentic Loading Phases\n                    if (_isAILoading)\n                      const SliverToBoxAdapter(\n                        child: Padding(\n                          padding: EdgeInsets.fromLTRB(20, 8, 20, 4),\n                          child: _AgentSearchingWidget(),\n                        ),\n                      ),"
if old_loading in n:
    n = n.replace(old_loading, new_loading, 1)
    changes += 1
    print('SUCCESS 2: loading indicator replaced')
else:
    print('FAIL 2: not found')

# 3. Replace results header
old_results = "                    // Search Results\n                    if (_matches.isNotEmpty) ...[\n                      const SliverToBoxAdapter(\n                        child: Padding(\n                          padding: EdgeInsets.fromLTRB(24, 20, 24, 10),\n                          child: Text('Best matches for you:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),\n                        ),\n                      ),"
new_results = "                    // Search Results\n                    if (_matches.isNotEmpty) ...[\n                      SliverToBoxAdapter(\n                        child: Padding(\n                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),\n                          child: _WorkersFoundBanner(\n                            count: _matches.length,\n                            serviceType: _currentRequest?.serviceType ?? 'Service',\n                          ),\n                        ),\n                      ),"
if old_results in n:
    n = n.replace(old_results, new_results, 1)
    changes += 1
    print('SUCCESS 3: results header replaced')
else:
    print('FAIL 3: not found')

# 4. Write new widget classes to a temp file, then read & insert
open('lib/screens/home_screen.dart', 'w', encoding='utf-8').write(n)
print(f'Phase 1 done. {changes} changes. Now adding widget classes...')
