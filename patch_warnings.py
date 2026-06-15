content = open('lib/screens/booking_flow_screen.dart', 'r', encoding='utf-8').read()
n = content.replace('\r\n', '\n')

# Fix 1: remove unused _stepIcons in _AgentStatusBanner (it's a duplicate - _TimelineStep has its own)
# The _AgentStatusBanner._stepIcons at line ~1794 is the one flagged
# Find _AgentStatusBanner class and check if it has _stepIcons defined but never used
# The _status getter uses _stepIcons[i], so it IS used. But the warning says it's unused.
# Actually the warning is that it's never used OUTSIDE the class via _AgentStatusBanner._stepIcons
# Let's check the context
import re

# Find all _stepIcons definitions
for m in re.finditer(r'static const _stepIcons = \[', n):
    print('_stepIcons def at char:', m.start())
    # Find which class it belongs to
    snippet_before = n[max(0, m.start()-500):m.start()]
    class_match = list(re.finditer(r'class \w+', snippet_before))
    if class_match:
        print('  belongs to class:', class_match[-1].group())
