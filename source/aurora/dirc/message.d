module aurora.dirc.message;

import aurora.dirc.irc;
import std.array;
import std.algorithm;
import std.conv;
import std.regex;
import std.stdio;
import std.string;

struct RawIRCMessage {
    string raw; // the raw message entirely

    string prefix;
    string command;
    string params;
    string trail;
}

struct NumericMsg {
    string raw;

    string prefix;
    ushort numeric;
    string params;
    string trail;
}

struct PingMsg {
    string raw;

    string response;
}

struct PrivMsg {
    string raw;

    string sender;
    string destination;
    string message;
}

interface MessageListener {
    public void onMessage(RawIRCMessage message);
}

class DefaultMessageListener : MessageListener {
    private IRCServer server;
    private string[] allowedNicks = [
        "tcw"
    ];

    this(IRCServer server) {
        this.server = server;
    }

    public void onMessage(RawIRCMessage message) {
        switch (message.command) {
            case "PING":
                PingMsg pingMsg = {
                    raw: message.raw,
                    response: message.trail
                };
                onPing(pingMsg);
                break;
            case "PRIVMSG":
                PrivMsg privMsg = {
                    raw: message.raw,
                    sender: message.prefix,
                    destination: message.params,
                    message: message.trail
                };
                onPrivMsg(privMsg);
                break;
            default:
                auto numericRegex = regex(r"(?P<numeric>\d+)");
                auto numericMatch = match(message.command, numericRegex);
                if(numericMatch) {
                    NumericMsg numericMsg = {
                        prefix: message.prefix,
                        numeric: to!ushort(numericMatch.captures["numeric"]),
                        params: message.params,
                        trail: message.trail
                    };
                    onNumericMsg(numericMsg);
                } else {
                    writefln("%s : %s : %s : %s", message.prefix, message.command,
                            message.params, message.trail);
                }
                break;
        }
    }

    public void onNumericMsg(NumericMsg message) {
        switch(message.numeric) {
            case 372: // MOTD
                break;
            case 376: // End of /MOTD command.
                foreach(channel; server.channels) {
                    RawIRCMessage joinMsg = {
                        raw: "JOIN " ~ channel
                    };
                    server.writeMessage(joinMsg);
                }
                break;
            default:
                break;
        }
    }

    public void onPrivMsg(PrivMsg message) {
        auto regex = regex(r"^(?P<nick>.+)!(?P<user>.+)@(?P<host>.+)$");
        auto match = match(message.sender, regex);
        auto nick = match.captures["nick"];
        auto user = match.captures["user"];
        auto host = match.captures["host"];
        auto authenticated = allowedNicks.canFind(nick);
        if(message.message[0] == ':') { // command
            auto args = message.message.split();
            auto cmd = args[0][1 .. $];
            auto arguments = args[1 .. $];
            switch(cmd) {
                case "allow":
                    if(!authenticated || arguments.length != 1) {
                        break;
                    }
                    allowedNicks ~= arguments[0];
                    PrivMsg msg = {
                        destination: message.destination,
                        message: "Given rights to " ~ arguments[0]
                    };
                    server.writePrivMsg(msg);
                    break;
                case "kill":
                    if(!authenticated) {
                        break;
                    }
                    std.c.process.exit(0);
                    break;
                case "join":
                    if(!authenticated || arguments.length != 1) {
                        break;
                    }
                    RawIRCMessage msg = {
                        raw: "JOIN " ~ arguments[0]
                    };
                    server.writeMessage(msg);
                    break;
                case "part":
                    if(!authenticated || arguments.length != 1) {
                        break;
                    }
                    RawIRCMessage msg = {
                        raw: "PART " ~ arguments[0]
                    };
                    server.writeMessage(msg);
                    break;
                default:
                    break;
            }
        }
        writefln("[%s] <%s> %s", message.destination, nick, message.message);
    }

    public void handleCommand(PrivMsg message, string nick, string command, string arguments) {
    }

    public void onPing(PingMsg message) {
        RawIRCMessage pong = {
            raw: "PONG " ~ message.response
        };
        server.writeMessage(pong);
    }

}
