"""Make Elyx's skill copies writable before the installer stamps them.

Patch the private ASAR during the build; application sources stay out of this
project. Keep packed offsets intact by appending the changed entry's data.
"""
import hashlib
import json
import struct
import sys
from pathlib import Path


def patch(archive):
    data = archive.read_bytes()
    _, header_size, _, json_size = struct.unpack_from('<IIII', data)
    header = json.loads(data[16:16 + json_size])
    entry = header
    for name in 'src/main/agent-resources/AgentToolsInstaller.ts'.split('/'):
        entry = entry['files'][name]
    payload = data[8 + header_size:]
    offset = int(entry['offset'])
    source = payload[offset:offset + entry['size']].decode()
    changes = [
        ('  access,\n', '  access,\n  chmod,\n'),
        (
            '      await cp(copy.source, copy.destination, { recursive: true })',
            '      await cp(copy.source, copy.destination, { recursive: true })\n'
            '      await chmod(copy.destination, 0o755)\n'
            "      await chmod(Path.join(copy.destination, 'SKILL.md'), 0o644)",
        ),
    ]
    for old, new in changes:
        if source.count(old) != 1:
            raise ValueError('Elyx installer changed; review the Nix permission patch')
        source = source.replace(old, new)
    content = source.encode()
    entry['offset'] = str(len(payload))
    entry['size'] = len(content)
    if 'integrity' in entry:
        integrity = entry['integrity']
        if integrity['algorithm'] != 'SHA256':
            raise ValueError('Unsupported ASAR integrity algorithm')
        integrity['hash'] = hashlib.sha256(content).hexdigest()
        block_size = integrity['blockSize']
        integrity['blocks'] = [
            hashlib.sha256(content[i:i + block_size]).hexdigest()
            for i in range(0, len(content), block_size)
        ]
    encoded = json.dumps(header, separators=(',', ':'), ensure_ascii=False).encode()
    string = struct.pack('<I', len(encoded)) + encoded
    string += b'\0' * (-len(string) % 4)
    pickle = struct.pack('<I', len(string)) + string
    archive.write_bytes(struct.pack('<II', 4, len(pickle)) + pickle + payload + content)


if __name__ == '__main__':
    patch(Path(sys.argv[1]))
