
"""
Kernel for execution of Links code for a Jupyter Notebook
"""

from metakernel import MetaKernel
import socket
import json

# Can use this to display images within notebook
from IPython.display import Image


HOST = "127.0.0.1"
PORT = 9000


class LinksKernel(MetaKernel):
    sock = None
    implementation = "Links Kernel"
    implementation_version = "1.0"
    language = "Links"
    language_info = {
        'name': 'links_kernel',
        'file_extension': '.links'
    }

    banner = "Links Kernel for code interaction!"

    def _init_socket(self):
        if self.sock == None:
            self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            try:
                self.sock.connect((HOST, PORT))
            except:
                raise RuntimeError("Unable to connect")

    def parse_json(self, inp):
        
        json_str = json.loads(inp)
        
        # Either an Exception or an Expression
        if not json_str["response"] == "definition":
            print(json_str["content"])


    def do_execute_direct(self, code, silent=False):
        
        self._init_socket()
        
        json_code = json.dumps({"input": code}) + "\n"

        try:
            self.sock.send(json_code.encode('utf-8'))
            
            recv = self.sock.recv(1024)
            self.parse_json(recv) 
        except:
            raise RuntimeError("Transmission failed")
        
           

if __name__ == '__main__':
    LinksKernel.run_as_main()
