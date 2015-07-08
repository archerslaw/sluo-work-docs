# QEMU Monitor Protocol Python class
#
# Copyright (C) 2009 Red Hat Inc.
#
# This work is licensed under the terms of the GNU GPL, version 2.  See
# the COPYING file in the top-level directory.

import socket, json, time, commands
from optparse import OptionParser

class QMPError(Exception):
    pass

class QMPConnectError(QMPError):
    pass

class QEMUMonitorProtocol:
    def connect(self):
        self.sock.connect(self.filename)
        data = self.__json_read()
        if data == None:
            raise QMPConnectError
        if not data.has_key('QMP'):
            raise QMPConnectError
        return data['QMP']['capabilities']

    def close(self):
        self.sock.close()

    def send_raw(self, line):
        self.sock.send(str(line))
        return self.__json_read()

    def send(self, cmdline, timeout=30, convert=True):
        end_time = time.time() + timeout
        if convert:
            cmd = self.__build_cmd(cmdline)
        else:
            cmd = cmdline
	    print("*cmdline = %s" % cmd)
        print cmd
        self.__json_send(cmd)
        while time.time() < end_time:
            resp = self.__json_read()
            if resp == None:
                return (False, None)
            elif resp.has_key('error'):
                return (False, resp['error'])
            elif resp.has_key('return'):
                return (True, resp['return'])


    def read(self, timeout=30):
        o = ""
        end_time = time.time() + timeout
        while time.time() < end_time:
            try:
                o += self.sock.recv(1024)
                if len(o) > 0:
                    break
            except:
                time.sleep(0.01)
        if len(o) > 0:
            return json.loads(o)
        else:
            return None

    def __build_cmd(self, cmdline):
        cmdargs = cmdline.split()
        qmpcmd = { 'execute': cmdargs[0], 'arguments': {} }
        for arg in cmdargs[1:]:
            opt = arg.split('=')
            try:
                value = int(opt[1])
            except ValueError:
                value = opt[1]
            qmpcmd['arguments'][opt[0]] = value
	print("*cmdline = %s" % cmdline)
        return qmpcmd

    def __json_send(self, cmd):
        # XXX: We have to send any additional char, otherwise
        # the Server won't read our input
        self.sock.send(json.dumps(cmd) + ' ')

    def __json_read(self):
        try:
            return json.loads(self.sock.recv(1024))
        except ValueError:
            return

    def __init__(self, filename, protocol="tcp"):
        if protocol == "tcp":
            self.filename = ("localhost", int(filename))
            self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        elif protocol == "unix":
            self.filename = filename
            print self.filename
            self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        #self.sock.setblocking(0)
        self.sock.settimeout(5)

if __name__ == "__main__":
    parser = OptionParser()
    parser.add_option('-n', '--num', dest='num', default='10', help='Times want to try')
    parser.add_option('-f', '--file', dest='port', default='8000', help='QMP port/filename')
    parser.add_option('-p', '--protocol', dest='protocol',default='tcp', help='QMP protocol')
    def usage():
        parser.print_help()
        sys.exit(1)

    options, args = parser.parse_args()

    print options
    if len(args) > 0:
        usage()

    num = int(options.num)
    qmp_filename = options.port
    qmp_protocol = options.protocol
    qmp_socket = QEMUMonitorProtocol(qmp_filename,qmp_protocol)
    qmp_socket.connect()
    qmp_socket.send("qmp_capabilities")
    for i in range(num):
	print ("")
	print("***** hot-plug virtio-scsi disk via 'blockdev-add' *****")
	print ("")
        qmp_socket.send({ "execute": "blockdev-add", "arguments": {'options' : {'driver': 'qcow2', 'id':'drive-disk1', "aio":"native", 'rerror':'stop', 'werror':'stop', 'file': {'driver': 'file', 'filename': '/home/my-data-disk1.qcow2'}, 'cache': { 'writeback': False, 'direct': True, 'no-flush': False }}} }, convert=False)
        qmp_socket.send("device_add driver=virtio-scsi-pci id=scsi1 bus=pci.0 addr=0x8")
	qmp_socket.send("device_add driver=scsi-hd drive=drive-disk1 id=data-disk1 bus=scsi1.0")
        time.sleep(2)
	print ("")

	print("***** hot-plug virtio-blk disk via 'blockdev-add' *****")
	print ("")
	qmp_socket.send({ "execute": "blockdev-add", "arguments": {'options' : {'driver': 'qcow2', 'id':'drive-disk2', "aio":"native", 'rerror':'stop', 'werror':'stop', 'file': {'driver': 'file', 'filename': '/home/my-data-disk2.qcow2'}, 'cache': { 'writeback': False, 'direct': True, 'no-flush': False }}} }, convert=False)
        qmp_socket.send("device_add driver=virtio-blk-pci drive=drive-disk2 id=data-disk2 bus=pci.0 scsi=on addr=0x9")
        time.sleep(2)
	print ("")

	print("***** hot-plug virtio-blk disk via '__com.redhat_drive_add' *****")
	print ("")
	qmp_socket.send("__com.redhat_drive_add file=/home/my-data-disk3.qcow2 format=qcow2 id=drive-disk3 aio=native")
        qmp_socket.send("device_add driver=virtio-blk-pci drive=drive-disk3 id=data-disk3 bus=pci.0 addr=0x10")
        time.sleep(2)
	print ("")

	print("***** hot-unplug virtio-scsi disk *****")
	print ("")
	qmp_socket.send("device_del id=data-disk1")
	qmp_socket.send("device_del id=scsi1")
	qmp_socket.send("__com.redhat_drive_del id=drive-disk1")
	time.sleep(2)
	print ("")

	print("***** hot-unplug virtio-blk disk *****")
	print ("")
	qmp_socket.send("device_del id=data-disk2")
	qmp_socket.send("__com.redhat_drive_del id=drive-disk2")
	time.sleep(2)
	print ("")

	print("***** hot-unplug virtio-blk disk *****")
	print ("")
	qmp_socket.send("device_del id=data-disk3")
	time.sleep(2)
	print ("")
    qmp_socket.close()
