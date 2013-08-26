import std.stdio;
import std.concurrency;

import aurora.dirc.irc;

void main() {
    auto irc = new IRCServer("irc.rizon.net", 6667, "aurora`bot", [
        "#lolwut"
    ]);
    irc.connect();
    irc.handle();
}
