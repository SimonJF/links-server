
"""
Example kernel for execution of Links code for a Jupyter Notebook
"""

from metakernel import MetaKernel
import re
import sys
import socket
import json

# Can use this to display images within notebook
from IPython.display import Image


HOST = "127.0.0.1"
PORT = 9001
SOCKET = socket.socket(socket.AF_INET, socket.SOCK_STREAM)


def parse_json(json):

	json_str = json.loads(json)

	if json_str["response"] == "definition":
		pass
	else:
		# Exception || Expression
		print(json_str["content"])


class LinksKernel(MetaKernel):
    implementation = "Links Kernel"
    implementation_version = "1.0"
    language = "Links"

    banner = "Links Kernel for code interaction!"

    def do_execute_direct(self, code, silent=False):
        """
        :param code:(str) to be executed
        :param silent:(bool) Should output be displayed
        :return: None
        """

        if not silent:


            json_code = json.dumps({"input": code})
            print("json query: " + json_code)

            try:
                SOCKET.send(json_code.encode('utf-8'))
                #recv = SOCKET.recv(1024)
                #print("json response: " + recv)
            except:
                print("\nTransmission failed\n")
            else:
                pass
                #parse_json(recv)


if __name__ == '__main__':
    from ipykernel.kernelapp import IPKernelApp

    try:
		SOCKET.connect((HOST, PORT))
    except:
		print("Socket Exception")
    else:
	    IPKernelApp.launch_instance(kernel_class=LinksKernel)
