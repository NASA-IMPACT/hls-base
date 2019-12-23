from setuptools import setup

setup(name='hlsfmask',
      version='0.1',
      description='Python FMask for HLS',
      url='',
      author='Sean Harkins',
      author_email='sean@developmentseed.org',
      license='MIT',
      packages=['hlsfmask'],
      scripts=['bin/hlsfmask_usgsLandsatStacked.py'],
      zip_safe=False)
