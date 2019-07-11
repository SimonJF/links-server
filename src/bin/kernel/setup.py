from setuptools import setup


setup(
    name='linkskernel',
    version='0.0.7',
    packages=['links_kernel'],
    description='Links kernel for Jupyter',
    long_description=open('README.txt').read(),
    author='Tom Davey & Simon Fowler',
    author_email='tomjackdavey@hotmail.com',
    url='https://github.com/SimonJF/links-server',
    install_requires=[
        'jupyter_client', 'IPython', 'ipykernel',
	'metakernel'
    ],
    classifiers=[
        'Intended Audience :: Developers',
	"License :: OSI Approved :: MIT License",
        'Programming Language :: Python :: 3',
    ],
)
