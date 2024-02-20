#!/usr/bin/python3
import os
import locale

if os.environ.get("HTTP_FRONT_END_HTTPS") == "on":
    request_scheme = "https"
elif  os.environ.get("REQUEST_SCHEME") is not None:
    request_scheme = os.environ.get("REQUEST_SCHEME")
else:
    request_scheme = "http"
print("Content-type: text/html\r\n\r\n")
print("<html><head></head><body>")
print("<font size=+1>Environment</font></br>")
for param in os.environ.keys():
   print("<b>%20s</b>: %s</br>" % (param, os.environ[param]))
if os.environ.get("HTTP_ORIGIN") is not None:
  print('Access-Control-Allow-Origin: '+os.environ["HTTP_ORIGIN"]+'</br>')
else:
  print('Access-Control-Allow-Origin: '+request_scheme+'://'+os.environ["HTTP_HOST"]+'</br>')
print('Preferred encoding: '+locale.getpreferredencoding(False))
print("</body></html>")