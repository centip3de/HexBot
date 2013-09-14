module stack;
import std.stdio;
import std.string;
import std.container;
import std.c.stdlib : exit;

auto stackP = SList!string([""]);

void push(string element)
{
	stackP.insert(element);
}

string pop()
{
	string data = stackP.front;
	stackP.removeFront(1);
	return data;
}
