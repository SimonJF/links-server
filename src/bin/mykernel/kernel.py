
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



    def do_execute_direct(self, code, silent=False):

        self._init_socket()
        code = code.rstrip()


        json_code = json.dumps({"input": code}) + "\n"

        try:
            self.sock.send(json_code.encode('utf-8'))
            recv = self.sock.recv(1024)
            json_str = json.loads(recv)

            to_return = json_str["content"]

            if json_str["response"] == "exception":
                self.Error(to_return)
            elif code[-1] == ';':
                # Semi-colon indicates no output
                pass
            else:
                display_content = {
                    'source': 'kernel',
                    'data': {
                        'text/plain': to_return,
                        'text/html': to_return
                    }, 'metadata': {}
                }

                self.send_response(self.iopub_socket, 'display_data', display_content)

        except KeyboardInterrupt as e:
            self.Error("***: KeyboardInterrupt")
            self.do_shutdown(True)
            self.sock.close()
            self.sock = None

        # Return using the following form replacing wikipedia with relevant URL:
        # miframe = "<iframe src=\"https://en.wikipedia.org/wiki/Main_Page\" allowfullscreen=\"\" width=\"900\" height=\"600\" frameborder=\"0\"></iframe>"


if __name__ == '__main__':
    LinksKernel.run_as_main()
