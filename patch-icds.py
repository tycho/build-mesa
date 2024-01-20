#!/usr/bin/python

import os
import json

def patch_icd(path):
    print(f"Patching {path}")
    icd = json.load(open(path, 'rt'))
    icd['ICD']['library_path'] = '.\\vulkan_dzn.dll'
    json.dump(icd, open(path, 'wt'))
	
def main():
	for root, dirs, files in os.walk("mesa.prefix"):
		for file in files:
			if "dzn_icd" in file:
				patch_icd(os.path.join(root, file))

if __name__ == "__main__":
	main()