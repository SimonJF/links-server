from ipykernel.kernelapp import IPKernelApp
from . import LinksKernel

IPKernelApp.launch_instance(kernel_class=LinksKernel)
