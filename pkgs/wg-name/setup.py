#!/usr/bin/env python3
from setuptools import setup, find_packages

setup(
    name='wg-name',
    version='0.0.1',
    python_requires='>=3.2',
    # Modules to import from other scripts:
    packages=find_packages(),
    # install_requires=["requests", "fire"],
    # Executables
    scripts=["wg-name"],
)
