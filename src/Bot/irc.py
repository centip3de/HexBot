import socket
import re
import os
from subprocess import Popen, PIPE, STDOUT

bot_owner = "centip3de"
nickname = "HexBot"
channel = "#coffeesh0p"
sock = socket.socket()
server = "irc.hackthissite.org"
sock.connect((server, 6667))
sock.send("USER " + nickname + " USING PYTHON BOT\r\n")
sock.send("NICK " + nickname + "\r\n")

while 1:
    data = sock.recv(512)
    print data
    if data[0:4] == "PING":
        sock.send(data.replace("PING", "PONG"))
        sock.send("MODE " + nickname + " +B\r\n")
        sock.send("JOIN " + channel + "\r\n")
    elif re.search("PRIVMSG " + channel + " :!h", data):	
        foo = data.split("!h")
        foo = foo[-1]
        foo = foo.split(":")
        bar = open("input.gl", "w")
        bar.write(foo[-1])
        bar.close()
        cproc = Popen(["../../bin/intr", "input.gl"], stdout = PIPE, close_fds = True)
        output = cproc.stdout.readlines()
        lines = ""
        for line in output:
            lines += line.rstrip('\n') + " "  
        sock.send("PRIVMSG " + channel + " :" + lines + "\r\n")
