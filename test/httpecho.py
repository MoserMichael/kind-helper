
import http.server
import socketserver
import urllib.parse
import datetime

HTTP_LISTEN_PORT=8000

class Handler(http.server.SimpleHTTPRequestHandler):

    def do_GET(self):

        print("get path {}".format(self.path))
        # Construct a server response.
        self.send_response(200)
        self.send_header('Content-type', 'text/html')
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        self.end_headers()

        url_parsed = urllib.parse.urlparse(self.path)
        query = url_parsed.query
        now = datetime.datetime.now()
        msg = "<h2>echo response</h2>"\
                "<br>Time: {}<br>Path: {}<br>Query: {}".\
                format(now.strftime("%Y-%m-%d %H:%M:%S"),\
                url_parsed.path,\
                url_parsed.query)

        self.wfile.write(msg.encode('utf-8'))


class TCPServer(socketserver.TCPServer):
    # Allow to restart the mock server without needing to wait for the socket
    # to end TIME_WAIT: we only listen locally, and we may restart often in
    # some workflows
    allow_reuse_address = True


print('Server listening on port 8000 {}'.format(HTTP_LISTEN_PORT))
httpd = TCPServer(('', HTTP_LISTEN_PORT), Handler)
httpd.serve_forever()
