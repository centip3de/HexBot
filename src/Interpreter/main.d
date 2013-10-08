import std.stdio;
import std.c.stdlib;
import cpu;

int main(string[] args)
{
	if(args.length != 2)
	{
		writeln("Usage: ./main <filename.gl>");
		exit(1);
	}
	run(args[1]);
	return 0;
}

