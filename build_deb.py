import os, tarfile, io, sys

staging = sys.argv[1]
deb_file = sys.argv[2]

ctrl_buf = io.BytesIO()
with tarfile.open(fileobj=ctrl_buf, mode='w:gz') as tar:
    for f in os.listdir(os.path.join(staging, 'DEBIAN')):
        tar.add(os.path.join(staging, 'DEBIAN', f), arcname=f)

data_buf = io.BytesIO()
with tarfile.open(fileobj=data_buf, mode='w:gz') as tar:
    for root, dirs, files in os.walk(staging):
        if 'DEBIAN' in root:
            continue
        for f in files:
            fp = os.path.join(root, f)
            arc = os.path.relpath(fp, staging)
            tar.add(fp, arcname='./' + arc)

with open(deb_file, 'wb') as out:
    out.write(b'!<arch>\n')

    def write_entry(name, data):
        header = name.ljust(16).encode() + b'0           0     100644  '
        header += str(len(data)).rjust(10).encode() + b'  0     U\n'
        out.write(header + data)
        if len(data) % 2:
            out.write(b'\n')

    write_entry('debian-binary/     ', b'2.0\n')
    write_entry('control.tar.gz/    ', ctrl_buf.getvalue())
    write_entry('data.tar.gz/       ', data_buf.getvalue())

print(f'Built {deb_file}: {os.path.getsize(deb_file)} bytes')
