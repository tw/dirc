module aurora.dirc.irc;

import std.conv;
import std.regex;
import std.stdio;
import std.string;
import std.socket;
import std.socketstream;

import aurora.dirc.message;

class IRCServer {
    private MessageListener listener;
    private string host;
    private ushort port;
    private string nick;
    public string[] channels;

    private TcpSocket socket;
    private SocketStream stream;

    this(string host, ushort port, string nick, string[] channels) {
        this.host = host;
        this.port = port;
        this.nick = nick;
        this.channels = channels;
        this.listener = new DefaultMessageListener(this);
    }

    public bool isConnected() {
        return this.socket !is null;
    }

    public void connect() {
        if(!isConnected()) {
            this.socket = new TcpSocket(new InternetAddress(this.host, this.port));
            this.stream = new SocketStream(this.socket);
            writeRaw("USER " ~ this.nick ~ " " ~ this.nick ~ " " ~ this.nick
                     ~ " :" ~ this.nick ~ "\n");
            writeRaw("NICK " ~ this.nick ~ "\n");
        }
    }

    public void disconnect() {
        if(isConnected()) {
            this.socket.close();
            this.socket = null;
        }
    }

    public void handle() {
        auto regex = regex(r"^(:(?P<prefix>\S+) )?(?P<command>\S+)( (?!:)(?P<params>.+?))?( :(?P<trail>.+))?$");
        while(isConnected()) {
            string line = to!string(this.stream.readLine()).chomp();
            auto match = match(line, regex);
            auto prefix = match.captures["prefix"].chomp();
            auto command = match.captures["command"].chomp();
            auto params = match.captures["params"].chomp();
            auto trail = match.captures["trail"].chomp();
            RawIRCMessage message = {
                raw: line,
                prefix: prefix,
                command: command,
                params: params,
                trail: trail
            };
            listener.onMessage(message);
        }
    }

    public void writeRaw(string raw) {
        this.stream.writeString(raw);
    }

    public void writeMessage(RawIRCMessage message) {
        writeRaw(message.raw ~ "\n");
    }

    public void writePrivMsg(PrivMsg message) {
        writeRaw("PRIVMSG " ~ message.destination ~ " :" ~ message.message ~ "\n");
    }

}
