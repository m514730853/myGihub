import os, sys

staging_dir = sys.argv[1]
bin_path = os.path.join(staging_dir, 'var/jb/usr/local/bin/getwifi_bin')
sh_path = os.path.join(staging_dir, 'var/jb/usr/local/bin/getwifi_sh')
wrapper_path = os.path.join(staging_dir, 'var/jb/usr/local/bin/getwifi')

wrapper = """#!/bin/sh
/var/jb/usr/local/bin/getwifi_bin "$@" 2>/dev/null
if [ $? -ne 0 ]; then
    /var/jb/usr/local/bin/getwifi_sh "$@"
fi
"""

with open(wrapper_path, 'w') as f:
    f.write(wrapper)

os.chmod(wrapper_path, 0o755)
os.chmod(bin_path, 0o755)
os.chmod(sh_path, 0o755)

print("Wrapper script created")
print(f"  getwifi -> tries getwifi_bin first, falls back to getwifi_sh")
