module stack;
import std.stdio;
import std.string;
import std.c.stdlib : exit;

struct stackT
{
	string[1024] contents;
	int top;
}

stackT stackP;

bool stackIsEmpty()
{
	return stackP.top <= 0;
}

void push(string element)
{
	int top = stackP.top++;
	stackP.contents[top] = element;
}

string pop()
{
	if(stackIsEmpty())
	{
		writeln("Error: Cannont pop element from empty stack!");
		exit(1);
	}
	int top = --stackP.top;
	string data = stackP.contents[top];
	return data;
}
