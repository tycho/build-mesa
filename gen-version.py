import hashlib
import os
import uuid

namespace_dozen = uuid.UUID('{b05032a3-fc69-4c76-a3ee-8278bd13c3c0}')
namespace_gl = uuid.UUID('{4de3da4c-e05d-4b95-acff-69dd6de1fbcf}')

version = open(os.path.join('mesa.src', 'VERSION'), 'rt').read().strip()
id_dozen = uuid.uuid3(namespace_dozen, version)
id_gl = uuid.uuid3(namespace_gl, version)

with open('version-dozen.iss', 'wt') as output:
    output.write(f'#define MESA_VERSION "{version}"\n')
    output.write(f'#define INSTALLER_UUID "{str(id_dozen)}"\n')
    output.close()

with open('version-gl.iss', 'wt') as output:
    output.write(f'#define MESA_VERSION "{version}"\n')
    output.write(f'#define INSTALLER_UUID "{str(id_gl)}"\n')
    output.close()
