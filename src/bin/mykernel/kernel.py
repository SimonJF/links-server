
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

def parse_json(json):
    json_str = json.loads(json)

    if json_str["response"] == "definition":
            pass
    else:
            # Exception || Expression
            print(json_str["content"])


class LinksKernel(MetaKernel):
    sock = None
    implementation = "Links Kernel"
    implementation_version = "1.0"
    language = "Links"

    banner = "Links Kernel for code interaction!"

    def _init_socket(self):
        if self.sock == None:
            self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            try:
                self.sock.connect((HOST, PORT))
            except:
                raise RuntimeError("Unable to connect")


    def do_execute_direct(self, code, silent=False):
        """
        :param code:(str) to be executed
        :param silent:(bool) Should output be displayed
        :return: None
        """
        self._init_socket()

        if not silent:
            json_code = json.dumps({"input": code})
            print("json query: " + json_code)

        try:
            self.sock.send(json_code.encode('utf-8'))
            print("after send")
            recv = self.sock.recv(1024)
            print("json response: " + recv)
            parse_json(recv)
        except:
            print("\nTransmission failed\n")

if __name__ == '__main__':
    LinksKernel.run_as_main()
    #from ipykernel.kernelapp import IPKernelApp
    #IPKernelApp.launch_instance(kernel_class=LinksKernel)
