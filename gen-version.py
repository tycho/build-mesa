import hashlib
import os
import uuid

namespace = uuid.UUID('{b05032a3-fc69-4c76-a3ee-8278bd13c3c0}')

version = open(os.path.join('mesa.src', 'VERSION'), 'rt').read().strip()
installer_id = uuid.uuid3(namespace, version)

with open('version.iss', 'wt') as output:
    output.write(f'#define MESA_VERSION "{version}"\n')
    output.write(f'#define INSTALLER_UUID "{str(installer_id)}"\n')
    output.close()
