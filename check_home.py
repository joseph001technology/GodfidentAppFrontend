lines = open('lib/screens/home/home_screen.dart','r',encoding='utf-8').readlines()
print('Total lines:', len(lines))
print('Last 10 lines:')
for i,l in enumerate(lines[-10:]):
    print(f'{len(lines)-10+i+1}: {l.rstrip()}')

# Count braces
open_count = ''.join(lines).count('{')
close_count = ''.join(lines).count('}')
print(f'\nOpen braces: {open_count}')
print(f'Close braces: {close_count}')
print(f'Difference: {open_count - close_count}')
