lines = open('lib/screens/home/home_screen.dart','r',encoding='utf-8').readlines()
# Remove the stray method signature at the end
lines = [l for i,l in enumerate(lines) if not (i == 1483 and 'Widget _buildDefaultRulesList' in l)]
open('lib/screens/home/home_screen.dart','w',encoding='utf-8').write(''.join(lines))
print('Removed stray line, new total:', len(lines))