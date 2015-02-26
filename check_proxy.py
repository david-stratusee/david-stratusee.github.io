#!/usr/bin/env python

import socket
import sys

def isproxyalive(proxy):
    host_port = proxy.split(":")
    if len(host_port) != 2:
        #sys.stderr.write('proxy host is not defined as host:port\n')
        return False
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(10)
    try:
        s.connect((host_port[0], int(host_port[1])))
    except Exception, e:
        #sys.stderr.write('proxy %s is not accessible\n' % proxy)
        #sys.stderr.write(str(e)+'\n')
        return False
    s.close()
    return True

if __name__ == '__main__':
    if isproxyalive(sys.argv[1]):
        sys.stdout.write('%u' % 1)
    else:
        sys.stdout.write('%u' % 0)
