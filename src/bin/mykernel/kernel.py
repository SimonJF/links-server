
"""
Kernel for execution of Links code for a Jupyter Notebook
"""

from metakernel import MetaKernel
import socket
import json
import re

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

    def print_json(self, inp):

        # Either an Exception or an Expression
        if not inp["response"] == "definition":
            print(inp["content"])

    """ # Shouldn't be necessary
    def find_delims(self, code, index):

        delims = []

        if ';' in code:
            if '{' in code:
                (before,_, after) = code.partition('{')
                if ';' in before:
                    delims = [x.start() + index + 1 for x in re.finditer(';', before)]

                (_,_,rest) = after.partition('}')
                return delims + self.find_delims(rest, index + code.find(rest))

            else:
                return [x.start() + index + 1 for x in re.finditer(';', code)]
        else:
            return []

    """
    def do_execute_direct(self, code, silent=False):

        self._init_socket()
        code = code.rstrip()

        #delims = self.find_delims(code, 0)
        #delims.insert(0,0)

        #lines = [code[i:j] for (i, j) in zip(delims, delims[1:])]

        #for l in lines:
        json_code = json.dumps({"input": code}) + "\n"

        try:
            self.sock.send(json_code.encode('utf-8'))
            recv = self.sock.recv(1024)
            json_str = json.loads(recv)

            #if json_str["response"] == "exception":
                #break

        except:
            raise RuntimeError("Transmission failed")
            # restart kernel maybe

        self.print_json(json_str)


if __name__ == '__main__':
    LinksKernel.run_as_main()
