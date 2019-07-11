
"""
Kernel for execution of Links code for a Jupyter Notebook
"""

from metakernel import MetaKernel
import socket
import json


HOST = "127.0.0.1"
PORT = 9000


class LinksKernel(MetaKernel):
    sock = None
    implementation = "Links Kernel"
    implementation_version = "1.0"
    language = "Links"
    language_info = {
        'name': 'links',
        'file_extension': '.links'
    }

    banner = "Links Kernel for code interaction!"

    # Connect to server where Links code is sent to be executed
    def _init_socket(self):
        if self.sock == None:
            self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            try:
                self.sock.connect((HOST, PORT))
            except:
                raise RuntimeError("Unable to connect")

    # Called when a cell is run in the notebook
    def do_execute_direct(self, code, silent=False):
        self._init_socket()
        code = code.rstrip()

        json_code = json.dumps({"input": code}) + "\n"

        try:
            # Send and receive code as a json
            self.sock.send(json_code.encode('utf-8'))
            recv = self.sock.recv(1024)
            json_str = json.loads(recv)

            response = json_str["content"]

            if json_str["response"] == "page":
                response = "<iframe src=\"http://localhost:8080{}\" width=\"900\" height=\"400\"></iframe>".format(response)

            if not code[-1] == ';':
                display_content = {
                    'source': 'kernel',
                    'data': {
                        'text/plain': response,
                        'text/html': response
                    }, 'metadata': {}
                }
                if json_str["response"] == "exception":
                    self.Error(response)
                else:
                    self.send_response(self.iopub_socket, 'display_data', display_content)

        except KeyboardInterrupt as e:
            self.Error("***: KeyboardInterrupt")
            self.do_shutdown(True)
            self.sock.close()
            self.sock = None
